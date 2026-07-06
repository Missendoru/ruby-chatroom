# ruby chatroom
this is my first proper GitHub repository.
open server.rb and it will open a connection on port 3000
from which you can do /help to see all commands available

games included
- Battleships (/play username sea)**
- Tic Tac Toe (/play username ttt)
- Rock Paper Scissors (/play username rps)
- RPG Battle (/play username battle)

** note regarding Battleships
the syntax for firing is "/fire Y X", and not the other way around
as this is how grids are usually made in the Ruby terminal as well.
I believe there is one offset on the X axis of the right "Target
radial" board but I will most likely fix it after I finish writing
this document.

commands available (also shown when doing /help)
/help - show options
/name [handle] - change profile ID
/players - list users
/play [handle] [ttt|rps|battle|sea] - request match
/accept - accept pending request
/decline - decline pending request
/clear - clear client history terminal
/quit - drop current game

there is infact some trace of a pfp feature I was testing out but I
didn't end up implementing due to the server freezing.

you can test this out on other two computers or play online with your
peers by using Hamachi or another program of the sort.

This repository was made by the likes of Natsumi Ushiromiya.