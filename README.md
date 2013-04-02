gamEvolve
=========

A tool for creating, sharing, and modifing online games using simple concepts. Try it online at http://cybercri.github.com/gamEvolve/

Inspired by both [Rich Hickey's notions of simplicity] and [Bret Victor's ideas on understanding programming], the goal of the project is to let people take other's games and easily modify them, or take several games and recombine them in novel ways. In order to do so, games must be written as a set of "atoms" that can be moved, copied, and forked with minimum refactoring hassle.

Currently under development in pre-alpha phase.


Contributions
-------------

The project is looking for contributors: though testing, bug reports, and pull requests.

In terms of development, we follow [Beck's Directive]:

1. Make it work
2. Make it right
3. Make it fast


Dependencies
------------

Compiling the project requires the following dependencies:

1. [Node.js] and [NPM]
2. NPM modules:
  - [Coffeescript]
  - [win-spawn]
  - [Docco]


Our GIT Workflow
----------------

https://github.com/CyberCRI/gamEvolve/wiki/Our-Git-workflow


Compiling
----------

https://github.com/CyberCRI/gamEvolve/wiki/Compiling


Documentation
-------------

https://github.com/CyberCRI/gamEvolve/wiki/Documentation


Code Review
-----------

https://github.com/CyberCRI/gamEvolve/wiki/Code-review


Regression Tests
----------------

https://github.com/CyberCRI/gamEvolve/wiki/Regression-Tests


Deployment
----------

https://github.com/CyberCRI/gamEvolve/wiki/Deployment


License
-------

Covered under the MIT open source license. All included libraries (see _Dependencies_) are covered under their own open source licenses.


[GitHub Flow]: http://scottchacon.com/2011/08/31/github-flow.html
[Node.js]: http://nodejs.org/
[NPM]: https://npmjs.org/
[Coffeescript]: http://coffeescript.org/
[win-spawn]: https://npmjs.org/package/win-spawn
[Docco]: http://jashkenas.github.com/docco/
[Coffeescript Style Guide]: https://github.com/polarmobile/coffeescript-style-guide
[Javascript Style Guide]: http://google-styleguide.googlecode.com/svn/trunk/javascriptguide.xml#Naming
[Beck's Directive]: http://c2.com/cgi/wiki?MakeItWorkMakeItRightMakeItFast
[Rich Hickey's notions of simplicity]: http://www.infoq.com/presentations/Simple-Made-Easy
[Bret Victor's ideas on understanding programming]: http://worrydream.com/LearnableProgramming/