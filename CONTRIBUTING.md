# Contributing to Tethera

Tethera is a personal project, made by one person. Bug reports and ideas are very welcome.

## Reporting a bug or suggesting an idea

Open an [issue](https://github.com/pabrowhat/tethera/issues/new/choose) and pick a template. For a bug, please say which version you use (Help > About) and which system, and describe the steps that lead to it.

Please do not attach a world with private content. Describe the problem, or make a small world that shows it.

## Code changes

Please open an issue first and describe what you want to change, so we do not both spend time on something that does not fit.

This repository is published from a separate development repository, so pull requests are not merged here as they are. If a change is accepted, the maintainer applies it in the development repository and credits you in the release notes.

If you still want to send code, please keep to these rules:

- One change, one topic. A small change is easier to review, and easier to accept or reject on its own.
- Godot 4.7 and GDScript with type annotations.
- Text shown to the user goes through `tr()` with an English key, for example `settings.title`. Add the translation to `locale/en.po` and `locale/ru.po`. The key stays the same in every language: a new language is a new translation file, not new keys.
- Interface colours come from the theme files in `themes/`, not from the code.

## Translations

Translations are a valued contribution too. You can improve an existing translation in `locale/ru.po`, or open an issue to ask about a new language.

By sending a contribution you agree that it is released under the [MIT license](LICENSE) of this project.
