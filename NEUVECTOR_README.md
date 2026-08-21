# 🛡️ NeuVector on Ubuntu with Docker

[![NeuVector](https://img.shields.io/badge/NeuVector-5.4.1-00A3E0?style=flat-square&logo=suse&logoColor=white)](https://open-docs.neuvector.com/)
[![Docker](https://img.shields.io/badge/Docker-29.x-2496ED?style=flat-square&logo=docker&logoColor=white)](https://docs.docker.com/)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-24.04_LTS-E95420?style=flat-square&logo=ubuntu&logoColor=white)](https://ubuntu.com/)
[![License](https://img.shields.io/badge/NeuVector-Apache_2.0-green?style=flat-square)](https://github.com/neuvector/neuvector/blob/main/LICENSE)
[![Status](https://img.shields.io/badge/deployment-standalone_docker-yellow?style=flat-square)](#️-limitations-of-the-docker-deployment)

> **📌 Purpose**
> Complete procedure for deploying **NeuVector on Ubuntu using Docker**, covering Docker API compatibility,
> TLS certificate regeneration, container deployment, multi-node enforcers, and verification.
>
> **⚠️ Read [Limitations](#️-limitations-of-the-docker-deployment) first.** The Docker deployment path is
> effectively unmaintained upstream. For production or multi-cluster use, deploy on Kubernetes via Helm.

---

## 📑 Table of Contents

- [📋 Requirements](#-requirements)
- [🧩 What the AIO Image Contains](#-what-the-aio-image-contains)
- [🐳 1. Check Docker API Compatibility](#-1-check-docker-api-compatibility)
- [❗ 2. Why Certificates Must Be Regenerated](#-2-why-certificates-must-be-regenerated)
- [🔐 3. Generate Self-Signed TLS Certificates](#-3-generate-self-signed-tls-certificates)
- [🚀 4. Deploy NeuVector (Controller Host)](#-4-deploy-neuvector-controller-host)
- [🔎 5. Verify the Deployment](#-5-verify-the-deployment)
- [🌐 6. Add Another Docker Node (Enforcer)](#-6-add-another-docker-node-enforcer)
- [🔬 7. Add the Scanner](#-7-add-the-scanner)
- [🧯 8. Troubleshooting](#-8-troubleshooting)
- [✅ 9. Verification Checklist](#-9-verification-checklist)
- [🏗️ Deployment Flow](#️-deployment-flow)
- [🔒 Security Notes](#-security-notes)
- [⚠️ Limitations of the Docker Deployment](#️-limitations-of-the-docker-deployment)
- [📚 References](#-references)

---

## 📋 Requirements

| Requirement | Description |
| ----------- | ----------- |
| 🐧 **OS** | Ubuntu 22.04 / 24.04 LTS |
| 🐳 **Docker** | Docker Engine installed and running |
| 🔑 **Privileges** | `sudo` access |
| 🔐 **OpenSSL** | For certificate generation |
| 🌐 **Network** | TCP `8443`, `10443`, `18300`, `18301`, `18400`, `18401` + UDP `18301` between nodes |
| 💾 **Memory** | ≥ 4 GB free (Manager is a JVM; scanner spikes 1–2 GB during scans) |
| 📦 **Images** | `neuvector/allinone`, `neuvector/enforcer`, `neuvector/scanner` |

---

## 🧩 What the AIO Image Contains

Verify what you are actually deploying:

```bash
docker inspect allinone --format '{{index .Config.Labels "neuvector.role"}}'
# controller+enforcer+manager
```

| Component | In `allinone`? | Purpose |
| --------- | -------------- | ------- |
| **Controller** | ✅ | Policy store, REST API (`:10443`), embedded Consul |
| **Manager** | ✅ | Web UI (`:8443`) |
| **Enforcer** | ✅ | Host agent — container discovery, DPI, process/file protection |
| **Scanner** | ❌ | **Separate image** since 5.x — see [§7](#-7-add-the-scanner) |

> 💡 In NeuVector 4.x the scanner was bundled into `allinone`. It was split out in 5.x.

---

## 🐳 1. Check Docker API Compatibility

NeuVector's bundled Docker client speaks **API version 1.24**. Docker Engine 28+ raised its minimum
supported API to **1.44** and will reject NeuVector's connection.

Check the effective minimum:

```bash
docker version --format 'Server={{.Server.Version}} MinAPI={{.Server.MinAPIVersion}}'
```

| Result | Action |
| ------ | ------ |
| `MinAPI=1.24` | ✅ Nothing to do |
| `MinAPI=1.44` | ⚠️ Apply the override below |

### ⚙️ Apply the override (systemd drop-in)

> Use a drop-in file — **do not edit `docker.service` directly**, package upgrades overwrite it.

```bash
sudo mkdir -p /etc/systemd/system/docker.service.d

sudo tee /etc/systemd/system/docker.service.d/api-version.conf >/dev/null <<'EOF'
[Service]
Environment="DOCKER_MIN_API_VERSION=1.24"
EOF

sudo systemctl daemon-reload
sudo systemctl restart docker
```

Verify:

```bash
systemctl show docker --property=Environment
docker version --format 'MinAPI={{.Server.MinAPIVersion}}'   # expect 1.24
```

> 🚨 **This is an environment variable, not a `daemon.json` key.** Adding `min-api-version` to
> `/etc/docker/daemon.json` has no effect.

> 🔁 **Apply on every host** running a NeuVector component that reads `docker.sock`.

---

## ❗ 2. Why Certificates Must Be Regenerated

The published `neuvector/allinone` image ships an internal CA that has **already expired**:

```text
/etc/neuvector/certs/internal/ca.cert
  notBefore = May 19 02:21:44 2016 GMT
  notAfter  = May 17 02:21:44 2026 GMT   ← EXPIRED
```

The leaf certificate (`cert.pem`) is valid until 2032, but its **issuing CA is expired**, so the whole
chain fails validation. The enforcer cannot complete its mTLS handshake with the controller:

```text
ERRO|AGT|main.waitForAdmission: Agent join request failed - error=rpc error: code = Unavailable
  desc = "transport: authentication handshake failed: x509: certificate has expired or is not yet
  valid: current time 2026-08-19T10:59:57Z is after 2026-05-17T02:21:44Z"
```

**Consequence:** controller and manager start normally, the UI loads, but the enforcer never joins —
so **no containers are ever discovered**. Symptoms look like a login failure, but the real cause is
the expired CA.

> ℹ️ `docker pull neuvector/allinone:latest` returns the same November 2024 digest — there is no fixed
> image upstream. Regenerating the certificates locally is the only remedy.

### 🎁 Side benefit

The original `cert.key` ships **inside a public Docker image**, meaning every default NeuVector Docker
deployment shares one publicly-downloadable private key. Generating your own is a strict security
improvement, independent of the expiry.

---

## 🔐 3. Generate Self-Signed TLS Certificates

NeuVector's internal TLS is a **closed trust system** — components verify each other against the same
CA. Any self-consistent CA + leaf pair works; it does not need to be publicly trusted.

```bash
mkdir -p certs/internal && cd certs/internal
```

### 🔑 Step 1 — CA key and certificate (10 years)

```bash
openssl req -x509 -newkey rsa:2048 -nodes \
  -keyout ca.key \
  -out ca.cert \
  -days 3650 \
  -subj "/C=US/ST=California/O=NeuVector Inc./CN=NeuVector" \
  -addext "basicConstraints=critical,CA:TRUE" \
  -addext "keyUsage=critical,keyCertSign,cRLSign"
```

### 📄 Step 2 — Leaf certificate extensions

```bash
cat > ext.cnf <<'EOF'
basicConstraints=CA:FALSE
keyUsage=digitalSignature,keyEncipherment,dataEncipherment
extendedKeyUsage=serverAuth,clientAuth
subjectAltName=DNS:NeuVector
subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid,issuer
EOF
```

> These match the original certificate's extensions exactly, so NeuVector's verification logic
> behaves identically.

### 🔑 Step 3 — Leaf key and CSR

```bash
openssl req -newkey rsa:2048 -nodes \
  -keyout cert.key \
  -out cert.csr \
  -subj "/C=US/ST=California/L=San Jose/O=NeuVector Inc./OU=NeuVector/CN=NeuVector"
```

### ✍️ Step 4 — Sign the leaf with the CA

```bash
openssl x509 -req \
  -in cert.csr \
  -CA ca.cert \
  -CAkey ca.key \
  -CAcreateserial \
  -out cert.pem \
  -days 3650 \
  -extfile ext.cnf
```

### 🧹 Step 5 — Clean up and set permissions

```bash
rm -f cert.csr ext.cnf ca.srl
chmod 660 ca.cert cert.pem cert.key
chmod 600 ca.key
```

### ✅ Step 6 — Verify

```bash
openssl verify -CAfile ca.cert cert.pem      # expect: cert.pem: OK
openssl x509 -in ca.cert   -noout -dates     # notAfter ≈ +10 years
openssl x509 -in cert.pem  -noout -dates
```

### 📦 Resulting files

| File | Mounted into container? | Notes |
| ---- | ----------------------- | ----- |
| `ca.cert` | ✅ | CA both sides verify against |
| `cert.pem` | ✅ | Leaf presented during handshake |
| `cert.key` | ✅ | Leaf private key |
| `ca.key` | ❌ | **Host only** — signing key, never needed by a container |

<details>
<summary>🔍 <strong>Optional: inspect certificate details</strong></summary>

```bash
openssl x509 -in cert.pem -text -noout
openssl x509 -in cert.pem -noout -subject
openssl x509 -in cert.pem -noout -issuer
```

</details>

> 🚨 **Generate once, distribute everywhere.** Every controller, enforcer, and scanner in the same
> NeuVector cluster must use the **identical** `ca.cert`, `cert.pem`, and `cert.key`. Generating
> separately per host produces mismatched CAs and the join silently fails.

---

## 🚀 4. Deploy NeuVector (Controller Host)

`compose.yaml`:

```yaml
services:
  allinone:
    image: neuvector/allinone:latest
    container_name: allinone
    restart: unless-stopped
    pid: host
    privileged: true
    environment:
      - CLUSTER_JOIN_ADDR=<YOUR SYSTEM IP>      # ← this host's real LAN IP
      - NV_PLATFORM_INFO=platform=Docker
      - CTRL_PERSIST_CONFIG=1                 # persist policy to /var/neuvector
    ports:
      - 8443:8443                             # Manager Web UI (HTTPS)
      - 10443:10443                           # Controller REST API
      - 18300:18300                           # controller cluster
      - 18301:18301                           # gossip (TCP)
      - 18301:18301/udp                       # gossip (UDP)
      - 18400:18400                           # enforcer datapath
      - 18401:18401                           # enforcer datapath
    volumes:
      - /lib/modules:/lib/modules:ro
      - /var/neuvector:/var/neuvector
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - /proc:/host/proc:ro
      - /sys/fs/cgroup:/host/cgroup:ro
      # 🔐 replacement certificates — required, see §2
      - ./certs/internal/ca.cert:/etc/neuvector/certs/internal/ca.cert
      - ./certs/internal/cert.pem:/etc/neuvector/certs/internal/cert.pem
      - ./certs/internal/cert.key:/etc/neuvector/certs/internal/cert.key
```

Find your IP for `CLUSTER_JOIN_ADDR`:

```bash
ip -4 addr show scope global | awk '/inet/ {print $2}'
```

Start it:

```bash
sudo mkdir -p /var/neuvector
sudo docker compose up -d
sudo docker compose logs -f          # wait ~45s for the controller
```

### 📁 Why individual file mounts

The three certificates are mounted **as individual files** into `/etc/neuvector/certs/internal/`,
not as a whole directory. NeuVector generates `adm_ca.cert` / `adm_ca.key` in that same directory at
runtime; mounting over the directory can mask them.

> ⚠️ **`CLUSTER_JOIN_ADDR` must be the host's real IP**, never `127.0.0.1` or `localhost`.
> The controller advertises this address for cluster membership.

---

## 🔎 5. Verify the Deployment

### 🐳 Containers and ports

```bash
docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"
sudo ss -tlnp | grep -E '8443|10443'
```

### 🔐 Effective certificate inside the container

```bash
docker exec allinone openssl x509 \
  -in /etc/neuvector/certs/internal/ca.cert -noout -dates
```

`notAfter` must be in the future.

### 📜 Logs — confirm the enforcer joined

```bash
docker logs allinone 2>&1 | grep -c 'certificate has expired'    # expect 0
docker logs allinone 2>&1 | grep -c 'Agent join request failed'  # expect 0
docker logs allinone 2>&1 | grep -o 'JoinedAt:[^ ]*' | tail -1   # expect a real timestamp
```

### 🌐 Web UI

```text
https://<HOST_IP>:8443
```

Self-signed certificate — accept the browser warning. Default login **`admin` / `admin`**.

> 🚨 **Change the admin password immediately.** That account controls a system with root on every
> joined host.

### 🔌 API verification

```bash
TOKEN=$(curl -sk -X POST https://127.0.0.1:10443/v1/auth \
  -H 'Content-Type: application/json' \
  -d '{"password":{"username":"admin","password":"admin"}}' \
  | python3 -c 'import sys,json; print(json.load(sys.stdin)["token"]["token"])')

curl -sk -H "X-Auth-Token: $TOKEN" https://127.0.0.1:10443/v1/workload | python3 -m json.tool
curl -sk -H "X-Auth-Token: $TOKEN" https://127.0.0.1:10443/v1/group    | python3 -m json.tool
curl -sk -H "X-Auth-Token: $TOKEN" https://127.0.0.1:10443/v1/enforcer | python3 -m json.tool
```

### 🧪 Prove discovery works

```bash
docker run -d --name web nginx:alpine
docker run -d --name client alpine sleep 3600
```

Both should appear within seconds under **Assets → Containers**, with `nv.web` / `nv.client` groups
auto-created in **Discover** mode.

---

## 🌐 6. Add Another Docker Node (Enforcer)

### 📤 Step 1 — Copy the certificates from the controller host

```bash
mkdir -p ~/neuvector/certs/internal
scp user@<CONTROLLER_IP>:/path/to/certs/internal/{ca.cert,cert.pem,cert.key} \
    ~/neuvector/certs/internal/
chmod 660 ~/neuvector/certs/internal/*
```

### ⚙️ Step 2 — Apply the Docker API override

Repeat [§1](#-1-check-docker-api-compatibility) on this host.

### 🚀 Step 3 — Deploy the enforcer

`compose.yaml`:

```yaml
services:
  enforcer:
    image: neuvector/enforcer:latest
    container_name: neuvector.enforcer
    restart: unless-stopped
    network_mode: host
    pid: host
    privileged: true
    environment:
      - CLUSTER_JOIN_ADDR=192.168.25.118      # ← controller host IP
      - NV_PLATFORM_INFO=platform=Docker
    volumes:
      - /lib/modules:/lib/modules:ro
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - /proc:/host/proc:ro
      - /sys/fs/cgroup:/host/cgroup:ro
      - ./certs/internal/ca.cert:/etc/neuvector/certs/internal/ca.cert
      - ./certs/internal/cert.pem:/etc/neuvector/certs/internal/cert.pem
      - ./certs/internal/cert.key:/etc/neuvector/certs/internal/cert.key
```

```bash
docker compose up -d
docker logs neuvector.enforcer 2>&1 | grep -iE 'join|certificate'
```

> ℹ️ **`network_mode: host` is deliberate.** With bridge networking the enforcer advertises its
> `172.x` container IP, which the controller cannot route back to.

### 🔌 Step 4 — Verify connectivity

```bash
nc -zv  <CONTROLLER_IP> 18300
nc -zvu <CONTROLLER_IP> 18301
```

### 🔐 Certificate consistency

```text
Controller Host              Enforcer Node
├── ca.cert     ─────────────► ca.cert      (identical)
├── cert.pem    ─────────────► cert.pem     (identical)
├── cert.key    ─────────────► cert.key     (identical)
└── ca.key      (host only, never copied to containers)
```

> ❌ **Different certificates between nodes = failed join, silently.** The node's containers simply
> never appear in the UI.

### 🔎 Automatic discovery

Once joined, that host's containers are discovered automatically — nothing to configure per container.

> ⚠️ **Groups are cluster-wide, not per-host.** A container on node 2 matching an existing group joins
> it and **inherits its mode immediately**. If that group is in **Protect**, the new container is
> enforced from its first packet — no learning period.

---

## 🔬 7. Add the Scanner

Not included in `allinone` on 5.x. Without it, all vulnerability pages render but stay permanently empty.

```yaml
  scanner:
    image: neuvector/scanner:latest
    container_name: neuvector.scanner
    restart: unless-stopped
    network_mode: host
    environment:
      - CLUSTER_JOIN_ADDR=192.168.25.118
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./certs/internal/ca.cert:/etc/neuvector/certs/internal/ca.cert
      - ./certs/internal/cert.pem:/etc/neuvector/certs/internal/cert.pem
      - ./certs/internal/cert.key:/etc/neuvector/certs/internal/cert.key
```

```bash
docker compose up -d scanner
curl -sk -H "X-Auth-Token: $TOKEN" https://127.0.0.1:10443/v1/scanner | python3 -m json.tool
```

No `privileged`, no `pid: host` — the scanner needs neither.

### 🔄 Keeping the CVE database current

The vulnerability database ships **inside the scanner image**:

```bash
docker compose pull scanner && docker compose up -d scanner
```

Schedule this weekly.

### 🧭 Division of labour

| Scan target | Collected by | Analysed by |
| ----------- | ------------ | ----------- |
| Registry images | scanner (pulls directly) | scanner |
| Running containers | **enforcer** | scanner |
| Host / node packages | **enforcer** | scanner |

> A node without an enforcer produces **no** container or host scan results, regardless of scanner count.

---

## 🧯 8. Troubleshooting

| Symptom | Log signature | Cause | Fix |
| ------- | ------------- | ----- | --- |
| Login fails, `Connection refused` on `:10443` | `StreamTcpException ... 127.0.0.1:10443` | Controller not running | Check the two rows below |
| Controller/enforcer restart loop | `Failed to initialize - error=Container list is empty` | Runtime enumeration failed | [§1](#-1-check-docker-api-compatibility) |
| Same, with a 400 | `client version 1.24 is too old. Minimum supported API version is 1.44` | Docker API floor too high | `DOCKER_MIN_API_VERSION=1.24` |
| UI loads, **no containers ever appear** | `x509: certificate has expired ... is after 2026-05-17` | Expired CA in image | [§3](#-3-generate-self-signed-tls-certificates) |
| Second node never appears | `certificate has expired` / connection error | Mismatched certs, or ports blocked | Copy identical certs; open `18300`/`18301` tcp+udp/`18400`/`18401` |
| Controller fails after config changes | Consul bind/advertise errors | Stale cluster state | `docker compose down && sudo rm -rf /var/neuvector/config` |
| Vulnerability pages always empty | — | No scanner registered | [§7](#-7-add-the-scanner) |
| Controller killed under load | `OOMKilled=true` | Insufficient memory | Free RAM or add swap |

### 🔍 Diagnostic one-liner

```bash
{
echo "=== ps ===";        docker compose ps
echo "=== listening ==="; sudo ss -tlnp | grep -E '8443|10443'
echo "=== state ===";     docker inspect allinone \
  --format 'OOM={{.State.OOMKilled}} Exit={{.State.ExitCode}} Restarts={{.RestartCount}}'
echo "=== errors ===";    docker logs allinone 2>&1 \
  | grep -iE 'failed to initialize|too old|certificate has expired|bind' | tail -20
echo "=== ca ===";        docker exec allinone openssl x509 \
  -in /etc/neuvector/certs/internal/ca.cert -noout -dates
echo "=== mem ===";       free -h
} 2>&1 | tee nv-diag.txt
```

---

## ✅ 9. Verification Checklist

- [ ] 🐳 `docker version` → `MinAPI` checked
- [ ] ⚙️ `DOCKER_MIN_API_VERSION=1.24` drop-in applied (if `MinAPI=1.44`)
- [ ] 🔄 `systemctl daemon-reload` + `restart docker` completed
- [ ] 🔐 CA key and certificate generated
- [ ] 🔑 Leaf certificate and key generated and signed
- [ ] ✅ `openssl verify -CAfile ca.cert cert.pem` → `OK`
- [ ] 📁 Three certificates mounted into `/etc/neuvector/certs/internal/`
- [ ] 🌐 `CLUSTER_JOIN_ADDR` set to the real host IP
- [ ] 📦 `allinone` container running
- [ ] 🚫 Zero `certificate has expired` entries in logs
- [ ] 🚫 Zero `Container list is empty` entries in logs
- [ ] 🤝 `JoinedAt` populated in the controller log
- [ ] 🔎 Test container discovered in the UI
- [ ] 🔬 Scanner deployed and registered
- [ ] 🌐 Additional enforcer nodes joined
- [ ] 🔐 Identical certificates on every node
- [ ] 🔒 Default `admin/admin` password changed
- [ ] 💾 Configuration exported / backed up

---

## 🏗️ Deployment Flow

```text
                 🐳 Check Docker MinAPIVersion
                              │
                    ┌─────────┴─────────┐
               MinAPI=1.44          MinAPI=1.24
                    │                   │
                    ▼                   │
       ⚙️ DOCKER_MIN_API_VERSION=1.24    │
          (systemd drop-in)              │
                    │                   │
                    ▼                   │
            🔄 daemon-reload             │
            ♻️ restart docker            │
                    │                   │
                    └─────────┬─────────┘
                              ▼
                 🔐 Generate CA + leaf certs
                              │
                              ▼
                     ✅ openssl verify
                              │
                              ▼
                📦 Deploy allinone + cert mounts
                              │
                              ▼
                 🔎 Confirm JoinedAt populated
                              │
                              ▼
                  🧪 Start a test container
                     → discovered? ──── NO ──► 🧯 Troubleshooting §8
                              │
                             YES
                              ▼
                     🔬 Deploy scanner
                              │
                              ▼
                📤 Copy certs → 🌐 enforcer nodes
                              │
                              ▼
                   🤝 Verify node join
                              │
                              ▼
              🛡️ Discover → Monitor → Protect
```

---

## 🔒 Security Notes

### ⚠️ Private key material

```text
ca.key      ← CA signing key   (never leaves the host, never mounted)
cert.key    ← leaf private key (mounted into every component)
```

**Do not:**

- ❌ Commit private keys to Git
- ❌ Upload to public repositories
- ❌ Share over unsecured channels
- ❌ Reuse lab certificates in production

**Do:**

- ✅ `chmod 600 ca.key`, `chmod 660 cert.key`
- ✅ Distribute via `scp`/secret manager, not email or chat
- ✅ Rotate on a schedule — **all hosts together**, a mixed-CA cluster fails silently
- ✅ Change the default `admin/admin` before exposing port 8443

### 🔑 Authentication model

The certificate **is** the authentication — there is no join token or shared secret.

| Property | Status |
| -------- | ------ |
| Per-node identity | ❌ all components share one leaf certificate |
| Revocation (CRL/OCSP) | ❌ not supported |
| Rotation | ⚠️ all-or-nothing across the cluster |

> 🚨 **Anyone holding `ca.cert` + `cert.pem` + `cert.key` and able to reach the cluster ports can join
> an enforcer.** Never expose `18300`/`18301`/`18400`/`18401` to the internet — UDP `18301` is Consul
> gossip. For remote hosts use a **VPN**, or run a separate cluster and **federate**.

### 🔓 Privilege

The enforcer requires `privileged: true`, `pid: host`, and `docker.sock`. **Any one of these is
sufficient for host root.** This is inherent to runtime security agents, not a NeuVector flaw.

Mitigations that matter more than capability-trimming:

- Pin images by digest, not `latest`
- Restrict who can `docker exec` into the container
- Audit-log access to the NeuVector host
- Never expose the Manager UI publicly

---

## ⚠️ Limitations of the Docker Deployment

Three independent signals that this path is unmaintained upstream:

1. 🕰️ **Docker API client is version 1.24** — a 2016-era API, requiring a compatibility override
2. 🔐 **Shipped CA expired 2026-05-17** — still expired in the published `latest` image
3. ⏳ **`DOCKER_MIN_API_VERSION` is a deprecation escape hatch** — it will eventually be removed

### 🚫 Features unavailable on Docker standalone

| Feature | Why |
| ------- | --- |
| **Admission control** | Kubernetes `ValidatingWebhook` — no API server to hook |
| **Platform scanning** | Scans the orchestrator; none present |
| **CRD / GitOps policy** | CRDs are a Kubernetes concept |
| **Federation** | Built around the Kubernetes deployment model |

> 💡 **Recommendation:** use this guide for a **single-host learning lab**. For production or
> multi-cluster deployments, use the Helm chart on Kubernetes — it talks CRI instead of the Docker
> API, is actively maintained, and is the only path offering the four features above.

---

## 📚 References

- 📖 [NeuVector — Deploying with Docker](https://open-docs.neuvector.com/deploying/docker)
- 📖 [NeuVector Documentation](https://open-docs.neuvector.com/)
- 💻 [neuvector/neuvector — GitHub](https://github.com/neuvector/neuvector)
- ⎈ [neuvector-helm — Kubernetes charts](https://github.com/neuvector/neuvector-helm)
- 🐳 [Docker Engine API versioning](https://docs.docker.com/reference/api/engine/version-history/)

---

## 📝 Notes

> 💡 **Tip:** Keep the NeuVector version, Docker version, certificate expiry dates, and compose files
> documented together. Record the certificate `notAfter` date — a silent cluster failure years from
> now will otherwise be very hard to diagnose.

> 🚨 **Important:** Always validate against the official documentation for the specific NeuVector
> release being deployed.
