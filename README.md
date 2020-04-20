[![](https://github.com/FiveTechSoft/screenshots/blob/master/fivetech_logo.gif?raw=true)](http://www.fivetechsoft.com "FiveTech Software")

# Harbour websocket server

Here you have a first prototype of a Harbour websocket server:

[https://github.com/FiveTechSoft/wsserver](https://github.com/FiveTechSoft/wsserver)

Basically this server allows you to communicate between a web browser and a Harbour app (no matter where it is!), using websockets.

In this version the websocket server implements an echo service, just to check that it properly works. It sends you back whatever you may send to it.
You can easily change its source code to implement any other conversation you may have in mind. It uses the port 9000 but you may use any other, just remember to change it in both wsserver.prg and in client.html

How to test it:

1. Build wsserver.exe using hbmk2 wsserver.prg -mt. Use the hbmk2 flag -mt to build it multithreading! 

2. Run wsserver.exe. It will display all messages that arrive to it. Press esc any time to end it.

3. [Click here](https://fivetechsoft.github.io//wsserver/client.html)

4. Whatever you send to the server from the web page, it will get back to you (sort of a karma reminder :-)

5. Write exit to tell the server to end your session. 

Enjoy it!

[![](https://github.com/FiveTechSoft/screenshots/blob/master/harbour_letters.jpg?raw=true)](https://harbour.github.io "The Harbour Project")
