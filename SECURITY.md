# Security policy

## Supported versions

Only the latest release receives fixes.

## Scope

Tethera works with local files and does not use the network. The parts most worth reporting are those that read files from outside: opening `.tether` files (zip archives), importing pictures, and reading worlds from a folder. Examples: a crafted file that makes the app crash, write outside the worlds folder, or use a very large amount of memory.

## Reporting a vulnerability

Please do not open a public issue for a security problem.

Use "Report a vulnerability" on the [Security tab](https://github.com/pabrowhat/tethera/security) of this repository. Say which version you use, what you did, and what happened. If you can, attach the file that causes it.

You will get a reply as soon as the maintainer can, usually within a week. This is a personal project, so there is no fixed schedule for fixes.
