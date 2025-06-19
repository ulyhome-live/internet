>[!NOTE]
> ## **step-by-step guidance** and a **customized `docker-compose.yaml`** for your scenario, including clear instructions on how to set up **Nextcloud All-in-One** (AIO) in an LXC container, **Nginx Proxy Manager** (NPM), and **ATT Fiber NAT/Gaming port forwarding** for your [nasmj.duckdns.org](http://nasmj.duckdns.org) DDNS.

---

## 1. **Network & Proxmox Host/IP Planning**

### **Your Setup Recap**

* **Proxmox Host:**

  * IP: `192.168.1.50/25` (mask means `.1.50` through `.1.126`)
  * Gateway: `192.168.1.254`
* **Nextcloud AIO (LXC 1000):**

  * IP: `192.168.1.60/24` *(You probably meant `/25` to match host, but `/24` also works)*
  * Gateway: `192.168.1.254`
* **Nginx Proxy Manager (NPM):**

  * Will run either on the **Proxmox host** or in **another container/VM**.
  * *Assume you want to run it in a Docker VM or another LXC* (not recommended to run docker directly on Proxmox host).

---

## 2. **Port Forwarding (NAT/Gaming on ATT Fiber BGW320-505)**

You’ll forward external traffic from ATT's public IP (`172.4.93.198`) to your internal services:

* **Ports for Nextcloud (LXC 1000):**

  * 3478 TCP & UDP → `192.168.1.60`
* **Ports for NPM (Proxy Manager):**

  * 80, 443 TCP → `192.168.1.50` (Proxmox host or wherever NPM is installed)

### **How To Set Up on ATT BGW320-505**

1. **Log into the modem's web interface**:
   Go to `http://192.168.1.254` in your browser.

2. **NAT/Gaming Tab**:

   * Go to **Firewall > NAT/Gaming**.
   * Find your device by IP in the dropdown (e.g., Proxmox host or LXC’s IP).

3. **Add Port Forwarding Rules**:

   * **HTTP/HTTPS for Proxy Manager:**

     * Service: *Custom Service*
     * Port Range: 80 - 80, Protocol: TCP, To Device: 192.168.1.50
     * Port Range: 443 - 443, Protocol: TCP, To Device: 192.168.1.50
   * **TURN/STUN for Nextcloud Talk:**

     * Port Range: 3478 - 3478, Protocol: TCP/UDP, To Device: 192.168.1.60

   *(If your Nginx Proxy Manager runs in another VM/LXC, change the destination accordingly)*

4. **Save** and **Reboot** modem if needed.

---

## 3. **DuckDNS & Dynamic DNS**

You already set up [nasmj.duckdns.org](http://nasmj.duckdns.org) and pointed it to your ATT public IP.

* Ensure your DuckDNS client is running somewhere in your network to keep your IP updated.

---

## 4. **docker-compose.yaml for Nginx Proxy Manager**

> **Note:**
> You typically run Nginx Proxy Manager (NPM) on the same network as Nextcloud or at least make it able to reach Nextcloud. Since Nextcloud AIO is in an LXC, we’ll expose its service port (usually 8080) to the local network and have NPM proxy to that.

### **A. Nginx Proxy Manager Compose File**

```yaml
version: "3"
services:
  npm:
    image: jc21/nginx-proxy-manager:latest
    container_name: nginx-proxy-manager
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
      - "81:81" # NPM UI
    environment:
      - TZ=America/Chicago # Change as needed
    volumes:
      - ./data:/data
      - ./letsencrypt:/etc/letsencrypt
    networks:
      - npmnet

networks:
  npmnet:
    driver: bridge
```

**Instructions:**

1. **SSH into your Docker host** (not LXC 1000, but either another VM or an LXC with Docker installed).
2. Create a folder (e.g., `mkdir ~/nginx-proxy-manager && cd ~/nginx-proxy-manager`).
3. Place above `docker-compose.yaml` file inside.
4. `docker compose up -d`

---

### **B. Nextcloud All-in-One (AIO) LXC**

1. **In your LXC 1000, install Docker** (if not already):

   ```bash
   apt update && apt install -y docker.io docker-compose
   ```

2. **Nextcloud AIO install** (see [Nextcloud AIO docs](https://github.com/nextcloud/all-in-one)):

   ```bash
   docker run \
     -it \
     --name nextcloud-aio-mastercontainer \
     --restart always \
     --publish 8080:8080 \
     --volume nextcloud_aio_mastercontainer:/mnt/docker-aio-config \
     -e APACHE_PORT=11000 \
     -e APACHE_IP_BINDING=0.0.0.0 \
     nextcloud/all-in-one:latest
   ```

   * **Note:**
     `8080:8080` exposes the AIO interface to the local network.

3. **Access the AIO installer UI** at
   `http://192.168.1.60:8080` in your browser.

---

## 5. **Proxy Setup (NPM → Nextcloud AIO)**

1. Go to Nginx Proxy Manager UI:
   `http://192.168.1.50:81`
2. Log in (default: `admin@example.com` / `changeme`)
3. Add a **Proxy Host**:

   * **Domain Name:** `nasmj.duckdns.org`
   * **Forward Hostname/IP:** `192.168.1.60`
   * **Forward Port:** `11000` *(as set above for Apache in Nextcloud AIO)*
   * **Enable SSL**: Request a new SSL certificate using Let's Encrypt.

     * Use DuckDNS email, enable "Force SSL".
   * **Save**.

---

## 6. **Troubleshooting/Best Practices**

* Make sure both NPM and Nextcloud AIO containers are reachable from each other (test with `curl` from Docker host to Nextcloud AIO IP and port).
* If the Nextcloud Talk server is still unreachable:

  * Double-check port 3478 forwarding (UDP and TCP).
  * Make sure your AIO's talk/turn/stun config points to your public DNS name: `nasmj.duckdns.org`.
* In Nextcloud, under **Settings > Administration > Overview**, warnings about setup can take a while to clear after a fresh install. Refresh after 5–10 min.
* Always restart both NPM and Nextcloud AIO after config changes.

---

## **Summary Diagram**

```
[Internet] --> [ATT BGW320-505 Modem]
         |           |    (Port 80/443 --> 192.168.1.50) 
         |           |    (Port 3478 --> 192.168.1.60)
         |           v
         |        [Proxmox Host 192.168.1.50]
         |         |        |
         |   [Docker VM/NPM]|
         |         |        |
         |         v        |
         |     [NPM on 192.168.1.50:80/443/81]
         |        |
         |     proxies to
         |        |
         v   [LXC 1000 - Nextcloud AIO 192.168.1.60:11000]
```

---

## **Final Checklist**

* [x] Proxmox network configured, LXC 1000 set to static IP.
* [x] ATT NAT/Gaming forwards 80/443 to NPM host, 3478 TCP/UDP to LXC 1000.
* [x] DuckDNS points to current ATT public IP.
* [x] Nginx Proxy Manager running via Docker Compose.
* [x] Nextcloud AIO running in LXC 1000, port 11000 open internally.
* [x] Proxy host configured for DuckDNS domain.
* [x] Nextcloud Talk configured with correct TURN server.

---

### **Let me know if you want a sample `/etc/network/interfaces` config for LXC, or any help with the DuckDNS client or testing connectivity!**

---

**If you have any part of the process already running, tell me what’s failing (UI, SSL, Talk, etc) and I’ll dig into it with you.**
