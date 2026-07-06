# ruby chatroom\n
this is my first proper GitHub repository.\n
open server.rb and it will open a connection on port 3000\n
from which you can do /help to see all commands available\n

games included\n
- Battleships (/play username sea)**\n
- Tic Tac Toe (/play username ttt)\n
- Rock Paper Scissors (/play username rps)\n
- RPG Battle (/play username battle)\n

** note regarding Battleships\n
the syntax for firing is "/fire Y X", and not the other way around\n
as this is how grids are usually made in the Ruby terminal as well.\n
I believe there is one offset on the X axis of the right "Target\n
radial" board but I will most likely fix it after I finish writing\n
this document.\n

commands available (also shown when doing /help)\n
/help - show options\n
/name [handle] - change profile ID\n
/players - list users\n
/play [handle] [ttt|rps|battle|sea] - request match\n
/accept - accept pending request\n
/decline - decline pending request\n
/clear - clear client history terminal\n
/quit - drop current game\n

there is infact some trace of a pfp feature I was testing out but I\n
didn't end up implementing due to the server freezing.\n

you can test this out on other two computers or play online with your\n
peers by using Hamachi or another program of the sort.\n

This repository was made by the likes of Natsumi Ushiromiya.\n
