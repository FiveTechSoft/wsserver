#include "inkey.ch"
#include "hbsocket.ch"

#define ADDRESS    "0.0.0.0" // Binding to all available networks, use "127.0.0.1" for localhost (only local connections)
#define PORT       9000
#define TIMEOUT    3000    // 3 seconds
#define CRLF       Chr( 13 ) + Chr( 10 )
#define FILEHEADER "data:application/octet-stream;base64,"
#define JSONHEADER "data:application/json;base64,"
#define HTMLHEADER "data:text/html;base64,"

//----------------------------------------------------------------//

function Main()

   local hListen, hSocket

   if ! File( "log.dbf" )
      DbCreate( "log.dbf", { { "COMPLETE",  "L",  1, 0 },;
                             { "OPCODE",    "N",  3, 0 },;
                             { "MASKED",    "L",  1, 0 },;
                             { "FRLENGTH",  "N",  6, 0 },;
                             { "PAYLENGTH", "N", 10, 0 },;
                             { "MASKKEY",   "C",  4, 0 },;
                             { "DATA",      "M", 10, 0 },;
                             { "HEADER",    "C", 50, 0 } } )
   endif

   if ! hb_mtvm()
      ? "multithread support required"
      return
   endif

   if Empty( hListen := hb_socketOpen( HB_SOCKET_AF_INET, HB_SOCKET_PT_STREAM, HB_SOCKET_IPPROTO_TCP ) )
      ? "socket create error " + hb_ntos( hb_socketGetError() )
   endif

   if ! hb_socketBind( hListen, { HB_SOCKET_AF_INET, ADDRESS, PORT } )
      ? "bind error " + hb_ntos( hb_socketGetError() )
   endif

   if ! hb_socketListen( hListen )
      ? "listen error " + hb_ntos( hb_socketGetError() )
   endif

   ? "Harbour websockets server running on port " + hb_ntos( PORT )

   while .T.
      if Empty( hSocket := hb_socketAccept( hListen,, TIMEOUT ) )
         if hb_socketGetError() == HB_SOCKET_ERR_TIMEOUT
            // ? "loop"
         ELSE
            ? "accept error " + hb_ntos( hb_socketGetError() )
         endif
      ELSE
         ? "accept socket request"
         hb_threadDetach( hb_threadStart( @ServeClient(), hSocket ) )
      endif
      if Inkey() == K_ESC
         ? "quitting - esc pressed"
         EXIT
      endif
   end

   ? "close listening socket"

   hb_socketShutdown( hListen )
   hb_socketClose( hListen )

return nil

//----------------------------------------------------------------//

function HandShaking( hSocket, cHeaders )   

   local aHeaders := hb_ATokens( cHeaders, CRLF )
   local hHeaders := {=>}, cLine 
   local cAnswer

   for each cLine in aHeaders
      hHeaders[ SubStr( cLine, 1, At( ":", cLine ) - 1 ) ] = SubStr( cLine, At( ":", cLine ) + 2 )
   next

   cAnswer = "HTTP/1.1 101 Web Socket Protocol Handshake" + CRLF + ;
             "Upgrade: websocket" + CRLF + ;
             "Connection: Upgrade" + CRLF + ;
             "WebSocket-Origin: " + ADDRESS + CRLF + ;
             "WebSocket-Location: ws://" + ADDRESS + ":" + hb_ntos( PORT ) + CRLF + ;
             "Sec-WebSocket-Accept: " + ;
             hb_Base64Encode( hb_SHA1( hHeaders[ "Sec-WebSocket-Key" ] + ;
                              "258EAFA5-E914-47DA-95CA-C5AB0DC85B11", .T. ) ) + CRLF + CRLF

   hb_socketSend( hSocket, cAnswer ) 

return nil   

//----------------------------------------------------------------//

function Unmask( cBytes )
   
   local lComplete := hb_bitTest( hb_bPeek( cBytes, 1 ), 7 )
   local nOpcode   := hb_bitAnd( hb_bPeek( cBytes, 1 ), 15 )
   local nFrameLen := hb_bitAnd( hb_bPeek( cBytes, 2 ), 127 ) 
   local nLength, cMask, cData, cChar, cHeader := ""

   do case
      case nFrameLen <= 125
         nLength = nFrameLen
         cMask = SubStr( cBytes, 3, 4 )
         cData = SubStr( cBytes, 7 )

      case nFrameLen = 126
         nLength = ( hb_bPeek( cBytes, 3 ) * 256 ) + hb_bPeek( cBytes, 4 )
         cMask   = SubStr( cBytes, 5, 4 )
         cData   = SubStr( cBytes, 9 )

      case nFrameLen = 127  
         nLength = NetworkBin2ULL( SubStr( cBytes, 3, 8 ) )  
         cMask   = SubStr( cBytes, 11, 4 )
         cData   = SubStr( cBytes, 15 )
   endcase 

   cBytes = ""
   for each cChar in cData
      cBytes += Chr( hb_bitXor( Asc( cChar ),;
                     hb_bPeek( cMask, ( ( cChar:__enumIndex() - 1 ) % 4 ) + 1 ) ) ) 
   next   

   do case
      case Left( cBytes, Len( FILEHEADER ) ) == FILEHEADER
         cBytes = hb_base64Decode( SubStr( cBytes, Len( FILEHEADER ) + 1 ) )
         cHeader = FILEHEADER 

      case Left( cBytes, Len( JSONHEADER ) ) == JSONHEADER
         cBytes = hb_base64Decode( SubStr( cBytes, Len( JSONHEADER ) + 1 ) )
         cHeader = JSONHEADER

      case Left( cBytes, Len( HTMLHEADER ) ) == HTMLHEADER
         cBytes = hb_base64Decode( SubStr( cBytes, Len( HTMLHEADER ) + 1 ) )
         cheader = HTMLHEADER
   endcase

   APPEND BLANK
   if log->( Rlock() )
      log->complete  := lComplete
      log->opcode    := nOpcode
      log->masked    := .T.
      log->frlength  := nFrameLen 
      log->paylength := nLength
      log->maskkey   := cMask
      log->data      := cBytes
      log->header    := cHeader
      log->( DbUnLock() )
   endif    

return cBytes 

//----------------------------------------------------------------//

function NetworkULL2Bin( n )

   local nBytesLeft := 64
   local cBytes := ""

   while nBytesLeft > 0
      nBytesLeft -= 8
      cBytes += Chr( hb_BitAnd( hb_BitShift( n, -nBytesLeft ), 0xFF ) )
   end

return cBytes

//----------------------------------------------------------------//

function NetworkBin2ULL( cBytes )

   local cByte, n := 0
   
   for each cByte in cBytes
      n += hb_BitShift( Asc( cByte ), 64 - cByte:__enumIndex() * 8 )
   next
   
return n

//----------------------------------------------------------------//

function Mask( cText, lEnd )

   local nLen := Len( cText ) 
   local cHeader 
   local lMsgIsComplete := .T., lMsgIsText := .T.
   local nFirstByte := 0
                  
   hb_default( @lEnd, .F. )

   if lMsgIsComplete
      nFirstByte = hb_bitSet( nFirstByte, 7 ) // 1000 0000
   endif

   if lMsgIsText 
      nFirstByte = hb_bitSet( nFirstByte, 0 ) // 1000 0001
   endif

   if lEnd
      nFirstByte = hb_bitSet( nFirstByte, 3 ) // 1000 1001
   endif   

   do case
      case nLen <= 125
         cHeader = Chr( nFirstByte ) + Chr( nLen )   

      case nLen < 65536
         cHeader = Chr( nFirstByte ) + Chr( 126 ) + ;
                   Chr( hb_BitShift( nLen, -8 ) ) + Chr( hb_BitAnd( nLen, 0xFF ) )
         
      otherwise 
         cHeader = Chr( nFirstByte ) + Chr( 127 ) + NetworkULL2Bin( nLen )   
   endcase

return cHeader + cText   

//----------------------------------------------------------------//

function ServeClient( hSocket )

   local cRequest, cBuffer := Space( 4096 ), nLen

   hb_socketRecv( hSocket, @cBuffer,,, 1024 )
   HandShaking( hSocket, RTrim( cBuffer ) )

   ? "new client connected"

   USE log SHARED

   while .T.
      cBuffer  = Space( 10000 )
      cRequest = ""

      if ( nLen := hb_socketRecv( hSocket, @cBuffer,,, TIMEOUT ) ) > 0  
         cRequest = UnMask( Left( cBuffer, nLen ) )
         
         do case
            case cRequest == "exit"
                 hb_socketSend( hSocket, Mask( "exiting", .T. ) )  // Close handShake
                 
            case cRequest == "exiting" // client answered to Close handShake
                 exit
                 
            otherwise     
                  ? cRequest
                  hb_socketSend( hSocket, Mask( cRequest ) )
         endcase

         // else
         //    if nLen == -1
         //       ? "recv() error:", hb_socketGetError() 
         //    endif
      endif 
   end

   ? "close socket"

   hb_socketShutdown( hSocket )
   hb_socketClose( hSocket )

   USE

return nil

//----------------------------------------------------------------//
