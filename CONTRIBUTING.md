# Contributing to Tethera

Tethera is a personal project, made by one person. Bug reports and ideas are very welcome.

## Reporting a bug or suggesting an idea

Open an [issue](https://github.com/pabrowhat/tethera/issues/new/choose) and pick a template. For a bug, please say which version you use (Help > About) and which system, and describe the steps that lead to it.

Please do not attach a world with private content. Describe the problem, or make a small world that shows it.

## Translations

The interface is in English and Russian. Better wording of a translation is welcome, and so is a new language. For a new language, open an issue first, so we agree on the file name and the scope.

## Code changes

Please open an issue first and describe what you want to change, so we do not both spend time on something that does not fit.

Keep one change to one topic. A small change is easier to check, and it can be accepted or declined on its own.

This repository is published from a separate development repository, so pull requests are not merged here as they are. If a change is accepted, the maintainer applies it in the development repository and credits you in the release notes.

If you still want to send code:

- Godot 4.7 and GDScript with type annotations.
- Text shown to the user is written with `tr()` and an English key, such as `settings.title`. The translation goes into `locale/en.po` and `locale/ru.po`. The key stays the same for every language: the app picks the translation for the current language. A new language is a new file in `locale/`, and existing keys are not renamed.
- Interface colours are not written in code. They come from the theme files in `themes/`, and a new colour is added to every theme file.

By sending a contribution you agree that it is released under the [MIT license](LICENSE) of this project.
