### Introducing pods
#### Why not just container?
When app consists of multiple process. They will communicate through:
- Inter-Process Communication(IPC)
- Locally stored files
Either way, It will require them to be on a same machine.<br><br>

You may think it makes sense then to run multiple processes in a single container, but you shoudln't do that because:
- Otherwise it's your responsibility to take care of **running processes**, and their **logs**.