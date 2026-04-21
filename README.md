# Cyqra

**Cyqra** ***[/ˈsiːkrə/]*** - is an experimental shell language that aims to seamlessly unify shell scripting and functional programming into a single coherent syntax.
## Features
> [!WARNING]  
> Cyqra is still in early development. Its syntax and features are subject to change.

The following are the core features established so far:
#### Variables
```sh
let x = 4
# shadowing - x is rebound, not reassigned
let x = "hello"       # x is now a string, the int is gone
echo $x               # "hello"
```
#### String interpolation
```sh
let name = "world"
echo "Hello ${name}"        # ${ } for expressions
echo "hello $name"           # $ident shorthand
echo "result: ${1 + 2 * 3}"  # arbitrary expressions inside
```
#### Functions
```sh
fn greet(name) {
   return "hello, ${name}!"
}
# last expression is the implicit return value
fn add(a, b) { a + b }
```
#### Hybrid syntax
```sh
greet("World")    #a function style call
greet World        # a shell style call
greet ("World")   # a shell style call with first arg as an expression
# same applies to external commands
echo("World")
echo World
echo ("World")
```
Cyqra disambiguates shell calls from expressions based on whether the name has been declared.
If unknown, the name is treated as a shell command and everything after it becomes arguments.
Consider the following:
```sh
echo - echo # echo is unknown -> shell call -> passes "- echo" as args
let echo = 366
echo - echo # echo is a variable -> arithmetic -> 366 - 366 = 0
```
> [!NOTE]
> Grab the latest nightly build from [Releases](https://github.com/Bqrry4/cyqra/releases/tag/nightly) to try it out.
