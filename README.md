# Harbour websocket server

Here you have a first prototype of a Harbour websocket server:

https://github.com/FiveTechSoft/wsserver

Basically this server allows you to communicate between a web browser and a Harbour app (no matter where it is!), using websockets.

It is actually working fine for messages <= 125 chars. I expect to complete it for all messages sizes soon. Help is welcome :-)

In this version the websocket server implements an echo service, just to check that it properly works. It sends you back whatever you may send to it.
You can easily change its source code to implement any other conversation you may have in mind.

How to test it:

1. Build wsserver.exe using hbmk2 wsserver.prg. Use the hbmk2 flag -mt to build it multithreading! 

2. Run wsserver.exe. It will display all messages that arrive to it. "loop" is shown on the screen. Press esc any time to end it.

3. If you have IIS or Apache installed on your PC, simply run this HTML page:

```
<html>
   <head>
   </head>
   <body>
   <input type="text" id="msg">
   <button onclick="Send( document.getElementById( 'msg' ).value )">Send</button>
   <script>
      var socket = new WebSocket( "ws://localhost:9000" );

      socket.onopen = function(e) {
      alert("[open] Connection established");
      alert("Sending to server");
      socket.send( "Harbour web sockets server" );
      };

      socket.onmessage = function(event) {
         alert(`[message] Data received from server: ${event.data}`);
      };

      socket.onclose = function(event) {
         if (event.wasClean) {
            alert(`[close] Connection closed cleanly, code=${event.code} reason=${event.reason}`);   
         } else {
            // e.g. server process killed or network down
            // event.code is usually 1006 in this case
            alert('[close] Connection died');
         }
      };

      socket.onerror = function(error) {
         alert(`[error] ${error.message}`);
      };

      function Send( cMsg ) {
         socket.send( cMsg );
      }
   </script>
   </body>
</html>
```
4. Whatever you send to the server from the web page, it will get back to you (sort of a karma reminder :-)

5. Write exit to tell the server to end your session. 

Enjoy it!
