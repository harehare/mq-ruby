use anyhow::Result;
use clap::Parser;
use eframe::egui;
use egui_commonmark::{CommonMarkCache, CommonMarkViewer};
use notify::{Watcher, RecursiveMode};
use std::path::PathBuf;
use std::sync::mpsc::{channel, Receiver};
use std::fs;
use std::time::{Duration, Instant};
use mq_markdown::Markdown;

const COLOR_BRAND_BLUE: egui::Color32 = egui::Color32::from_rgb(97, 175, 239); // #61AFEF
const _COLOR_BRAND_DARK: egui::Color32 = egui::Color32::from_rgb(43, 87, 115);  // #2B5773

#[derive(Parser, Debug)]
#[command(author, version, about, long_about = None)]
struct Args {
    /// Markdown file to preview
    file: Option<PathBuf>,
}

fn main() -> Result<()> {
    let args = Args::parse();

    let options = eframe::NativeOptions {
        viewport: egui::ViewportBuilder::default()
            .with_inner_size([1280.0, 720.0])
            .with_title("MQ Desktop"),
        ..Default::default()
    };

    eframe::run_native(
        "MQ Desktop",
        options,
        Box::new(|cc| {
            let mut app = MQApp::new(cc, args.file);
            app.load_file();
            Ok(Box::new(app))
        }),
    ).map_err(|e| anyhow::anyhow!("eframe error: {}", e))
}

struct TocEntry {
    level: u32,
    text: String,
}

#[derive(PartialEq)]
enum ViewMode {
    Original,
    QueryResult,
}

struct MQApp {
    file_path: Option<PathBuf>,
    markdown_content: String,
    query: String,
    query_result: Option<String>,
    toc: Vec<TocEntry>,
    cache: CommonMarkCache,
    rx: Option<Receiver<notify::Result<notify::Event>>>,
    _watcher: Option<notify::RecommendedWatcher>,
    last_query_change: Option<Instant>,
    view_mode: ViewMode,
    dark_mode: bool,
}

impl MQApp {
    fn new(cc: &eframe::CreationContext<'_>, file_path: Option<PathBuf>) -> Self {
        let (tx, rx) = channel();
        let mut watcher = None;
        let ctx = cc.egui_ctx.clone();

        if let Some(ref path) = file_path {
            let mut w = notify::recommended_watcher(move |res| {
                if tx.send(res).is_ok() {
                    ctx.request_repaint();
                }
            }).expect("Failed to create watcher");
            w.watch(path, RecursiveMode::NonRecursive).expect("Failed to watch file");
            watcher = Some(w);
        }

        Self {
            file_path,
            markdown_content: String::new(),
            query: "select *".to_string(),
            query_result: None,
            toc: Vec::new(),
            cache: CommonMarkCache::default(),
            rx: Some(rx),
            _watcher: watcher,
            last_query_change: None,
            view_mode: ViewMode::QueryResult,
            dark_mode: true,
        }
    }

    fn load_file(&mut self) {
        if let Some(ref path) = self.file_path {
            if let Ok(content) = fs::read_to_string(path) {
                self.markdown_content = content;
                self.update_toc();
                self.run_query();
            }
        }
    }

    fn update_toc(&mut self) {
        let mut toc = Vec::new();
        if let Ok(markdown) = self.markdown_content.parse::<Markdown>() {
            for node in &markdown.nodes {
                self.extract_headings(node, &mut toc);
            }
        }
        self.toc = toc;
    }

    fn extract_headings(&self, node: &mq_markdown::Node, toc: &mut Vec<TocEntry>) {
        use mq_markdown::Node;
        match node {
            Node::Heading(h) => {
                let mut text = String::new();
                for child in &h.values {
                    self.extract_text(child, &mut text);
                }
                toc.push(TocEntry {
                    level: h.depth as u32,
                    text,
                });
            }
            Node::Blockquote(b) => {
                for child in &b.values {
                    self.extract_headings(child, toc);
                }
            }
            Node::List(l) => {
                for child in &l.values {
                    self.extract_headings(child, toc);
                }
            }
            _ => {}
        }
    }

    fn extract_text(&self, node: &mq_markdown::Node, text: &mut String) {
        use mq_markdown::Node;
        match node {
            Node::Text(t) => text.push_str(&t.value),
            Node::CodeInline(c) => text.push_str(&c.value),
            Node::Emphasis(e) => {
                for child in &e.values {
                    self.extract_text(child, text);
                }
            }
            Node::Strong(s) => {
                for child in &s.values {
                    self.extract_text(child, text);
                }
            }
            Node::Delete(d) => {
                for child in &d.values {
                    self.extract_text(child, text);
                }
            }
            _ => {}
        }
    }

    fn run_query(&mut self) {
        let mut engine = mq_lang::DefaultEngine::default();
        engine.load_builtin_module();

        let input = mq_lang::parse_markdown_input(&self.markdown_content);

        match input {
            Ok(input_values) => {
                match engine.eval(&self.query, input_values.into_iter()) {
                    Ok(results) => {
                        if results.is_empty() {
                            self.query_result = Some("No results found.".to_string());
                        } else {
                            let result_strings: Vec<String> = results.into_iter().map(|v| {
                                match v {
                                    mq_lang::RuntimeValue::Markdown(node, _) => node.to_string(),
                                    mq_lang::RuntimeValue::String(s) => s,
                                    _ => format!("{:?}", v),
                                }
                            }).collect();
                            self.query_result = Some(result_strings.join("\n\n"));
                        }
                    }
                    Err(e) => {
                        self.query_result = Some(format!("Query Error: {}", e));
                    }
                }
            }
            Err(e) => {
                self.query_result = Some(format!("Parse Error: {}", e));
            }
        }
    }

    fn apply_styling(&self, ctx: &egui::Context) {
        if self.dark_mode {
            ctx.set_visuals(egui::Visuals::dark());
        } else {
            ctx.set_visuals(egui::Visuals::light());
        }
    }
}

impl eframe::App for MQApp {
    fn update(&mut self, ctx: &egui::Context, _frame: &mut eframe::Frame) {
        self.apply_styling(ctx);

        let mut should_reload = false;
        if let Some(ref rx) = self.rx {
            while let Ok(_) = rx.try_recv() {
                should_reload = true;
            }
        }
        if should_reload {
            self.load_file();
        }

        if let Some(last_change) = self.last_query_change {
            if last_change.elapsed() >= Duration::from_millis(300) {
                self.run_query();
                self.last_query_change = None;
            } else {
                ctx.request_repaint_after(Duration::from_millis(100));
            }
        }

        egui::SidePanel::left("toc_panel")
            .resizable(true)
            .default_width(250.0)
            .show(ctx, |ui| {
                ui.add_space(10.0);
                ui.heading(egui::RichText::new("Contents").color(COLOR_BRAND_BLUE));
                ui.separator();
                egui::ScrollArea::vertical().show(ui, |ui| {
                    for entry in &self.toc {
                        let indent = (entry.level as f32 - 1.0) * 12.0;
                        ui.add_space(4.0);
                        ui.horizontal(|ui| {
                            ui.add_space(indent);
                            if ui.selectable_label(false, &entry.text).clicked() {
                                // Scroll logic would go here
                            }
                        });
                    }
                });
            });

        egui::TopBottomPanel::top("header_panel").show(ctx, |ui| {
            ui.horizontal(|ui| {
                ui.heading(egui::RichText::new("mq").strong().color(COLOR_BRAND_BLUE));
                ui.label("desktop");

                ui.with_layout(egui::Layout::right_to_left(egui::Align::Center), |ui| {
                    if ui.button(if self.dark_mode { "🌙" } else { "☀️" }).clicked() {
                        self.dark_mode = !self.dark_mode;
                    }
                    ui.separator();
                    if let Some(ref path) = self.file_path {
                        ui.label(egui::RichText::new(path.to_string_lossy()).small());
                    }
                });
            });
        });

        egui::TopBottomPanel::top("query_panel").show(ctx, |ui| {
            ui.add_space(5.0);
            ui.vertical(|ui| {
                ui.horizontal(|ui| {
                    ui.label(egui::RichText::new("Query").strong());
                    let response = ui.add(
                        egui::TextEdit::singleline(&mut self.query)
                            .desired_width(f32::INFINITY)
                            .hint_text("e.g. select * where .h2")
                    );
                    if response.changed() {
                        self.last_query_change = Some(Instant::now());
                    }
                });

                ui.horizontal(|ui| {
                    ui.selectable_value(&mut self.view_mode, ViewMode::QueryResult, "Query Result");
                    ui.selectable_value(&mut self.view_mode, ViewMode::Original, "Original Preview");

                    ui.with_layout(egui::Layout::right_to_left(egui::Align::Center), |ui| {
                        let button = egui::Button::new(egui::RichText::new("Run").color(egui::Color32::WHITE))
                            .fill(COLOR_BRAND_BLUE);
                        if ui.add(button).clicked() {
                            self.run_query();
                            self.last_query_change = None;
                        }
                    });
                });
            });
            ui.add_space(5.0);
        });

        egui::CentralPanel::default().show(ctx, |ui| {
            egui::ScrollArea::vertical().show(ui, |ui| {
                let display_content = match self.view_mode {
                    ViewMode::QueryResult => self.query_result.as_deref().unwrap_or("No query results yet."),
                    ViewMode::Original => &self.markdown_content,
                };
                if display_content.is_empty() {
                    ui.centered_and_justified(|ui| {
                        ui.label("No content to display.");
                    });
                } else {
                    CommonMarkViewer::new().show(ui, &mut self.cache, display_content);
                }
            });
        });
    }
}
