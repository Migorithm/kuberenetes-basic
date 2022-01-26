### Introducing pods
#### Why not just container?
When app consists of multiple process. They will communicate through:
- Inter-Process Communication(IPC)
- Locally stored files
Either way, It will require them to be on a same machine.<br><br>

You may think it makes sense then to run multiple processes in a single container, but you shoudln't do that because:
- Otherwise it's your responsibility to take care of **running processes**, and their **logs**.

#### Understanding Pods
Because you're not supposed to group multiple processes into a single container, it's obvious you need another *higher-level construct* that will:
- Allow you to bind containers
- Manage them as a single unit by providing them with the same environment.
<br>

The question is, however, how *isolated* are containers in a Pod? Simply put, you want them to share *CERTAIN* resources but *NOT ALL*.
- K8S achieves this goal by configuring to have all containers in a pod share the same set of Linux namespaces instead of each container having its own set.
- They share:
    - Network namespace : Therefore, **IP** and **port** spaces. 
        - In fact, containers of different pods can never run into port conflicts.
        
        **Flat Network**
        - All pods in a K8S cluster reside in a single flat, shared, network address space, meaning every Pod can access every other pod at the other Pod's IP address.
        - No NAT(Network Address Translation) gateways exist between them. 
    - UTS namespace : Unix Time Sharing that allows a single system to have different host and domain name to different process
    - IPC namespace
- They DON'T share:
    - filesystem
        - This could be changed when we use *volume* though.
<br>


