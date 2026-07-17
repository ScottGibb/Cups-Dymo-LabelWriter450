# Changelog

## [3.0.0](https://github.com/ScottGibb/Cups-Dymo-LabelWriter450/compare/v2.0.0...v3.0.0) (2026-07-17)


### ⚠ BREAKING CHANGES

* Existing client queues must use the model-specific DYMO LabelWriter 450 driver and the matching platform helper; generic, AirPrint, and class-driver queues are no longer supported.

### Features

* add Bonjour auto discovery ([4104221](https://github.com/ScottGibb/Cups-Dymo-LabelWriter450/commit/410422109adb6d552cd615e10aac60008b22e433))
* **ci:** Overhaul CI ([7437e33](https://github.com/ScottGibb/Cups-Dymo-LabelWriter450/commit/7437e33b2c588cad0aca30d171b7af8a84dc26df))
* **clients:** add Linux and Windows queue helpers ([9daf9f1](https://github.com/ScottGibb/Cups-Dymo-LabelWriter450/commit/9daf9f131f49f414d6b7be36bc26ad3b094be599))
* Codex Generated Overhaul ([3f06124](https://github.com/ScottGibb/Cups-Dymo-LabelWriter450/commit/3f061243facf863c58dcc1d833d57884909d38c1))
* require platform-specific client setup ([fb3ab5c](https://github.com/ScottGibb/Cups-Dymo-LabelWriter450/commit/fb3ab5c54b3eeae5550898398f707f17c4dfd17f))


### Bug Fixes

* **clients:** parameterize Raspberry Pi IPP URI ([637a2fb](https://github.com/ScottGibb/Cups-Dymo-LabelWriter450/commit/637a2fbb757ea276edc571425370ae107157d9ff))
* dclint ([c89fc11](https://github.com/ScottGibb/Cups-Dymo-LabelWriter450/commit/c89fc113ee6e15d7d7fab44cd7f4c20c3573b354))
* **macos:** prevent DYMO jobs being filtered twice ([af72d98](https://github.com/ScottGibb/Cups-Dymo-LabelWriter450/commit/af72d984e800a5c53dc3dbae5085719af71273f4))
