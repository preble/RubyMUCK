# RubyMUCK

RubyMUCK is a Ruby adaptation of [TinyMUCK][]/[TinyMUD][]. In other words, it's a server for a text-based, multi-user, user-changeable world. Once running, the server is accessible over telnet. It was written in Ruby in 2007 by Adam Preble, when he was learning Ruby, which means that there are probably some really bad patterns in use here.

## Status

RubyMUCK was begun on October 17 2007; it is still very much in its Alpha phase, as it was then.

Release notes can be found in docs/release_notes.txt.

## Features

- Multithreaded TCP server allowing multiple players to interact.
- Say/pose and shortcut versions ('"' and ':').
- Basic TinyMUCK-style building commands: @dig, @action, @open, @link, etc.
- Path-accessible property tree (prop command).
- TinyMUCK-style notification fields for actions: succ/osucc/drop/odrop with basic interpreted language.
- Database for persistence between server start/stop; non-blocking (background) database saves.

## Installation/Instructions

- Configure the server by editing config.rb.
- Create a new database with `rake newdb`.
- Start the server with `rake run`.

## License/Disclaimer

RubyMUCK is provided under the [Creative Commons Attribution-Noncommercial-Share Alike 3.0][license] license. The software is provided "as is", without warranty of any kind, express or implied. Use at your own risk.

[license]: http://creativecommons.org/licenses/by-nc-sa/3.0/
[TinyMUCK]: http://en.wikipedia.org/wiki/MUCK
[TinyMUD]: http://en.wikipedia.org/wiki/TinyMUD
