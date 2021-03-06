job "plex" {
  region = "global"
  datacenters = ["dc1"]

  group "plex" {
    count = 1
    network {
        port "http" { to =   "32400" }
        port "port_1" { to = "8324" }
        port "port_2" { to = "32469" }
        port "port_3" { to = "1900" }
        port "port_4" { to = "32410" }
        port "port_5" { to = "32412" }
        port "port_6" { to = "32413" }
        port "port_7" { to = "32414" }
    }

    task "plex" {
      driver = "podman"
      env {
        TZ   = "Europe/Paris"
        VERSION="docker"
      }
      config {
        #image = "ghcr.io/rootless-homeserver/plex-pms:latest"
        image = "lscr.io/linuxserver/plex"
        force_pull = "true"
        ports = ["http","port_1","port_2","port_3","port_4","port_5","port_6","port_7"]
        logging = {
          driver = "nomad"
        }
        volumes = [
          "/mnt/tank/storage/config/plex:/config",
          "/mnt/tank/storage/config/certs:/certs",
          "/mnt/tank/storage/media/videos:/data/media/videos",
          "local/run:/etc/services.d/plex/run",
          "local/empty:/etc/cont-init.d/40-chown-files",
          #"local/claim:/etc/cont-init.d/99-custom-scripts",
          "secret/cert.pem:/certs/certs.pem",
          "secret/cert.key:/certs/certs.key",
        ]
        tmpfs = [
          "/transcode"
        ]
        devices = [
          "/dev/dri"
        ]
      }
      template{
        data = <<EOF
#!/usr/bin/with-contenv bash
echo Nothing to do
EOF
        destination = "local/empty"
      }
      template{
        data = <<EOF
#!/usr/bin/with-contenv bash

echo "Starting Plex Media Server as root"
export PLEX_MEDIA_SERVER_INFO_MODEL=$(uname -m)
export PLEX_MEDIA_SERVER_INFO_PLATFORM_VERSION=$(uname -r)
exec s6-setuidgid root /usr/lib/plexmediaserver/Plex\ Media\ Server
EOF
        destination = "local/run"
      }

      template {
        data = <<EOF
{{ with secret "pki_int/issue/techunter-io" "common_name=plex.ix.techunter.io" "ttl=30d" }}{{ .Data.private_key }}{{ end }}
EOF

        destination = "secret/cert.key"
      }
      template {
        data = <<EOH
{{ with secret "pki_int/issue/techunter-io" "common_name=plex.ix.techunter.io" "ttl=30d" }}
{{ .Data.certificate }}
{{ end }}
      EOH

        destination = "secret/cert.pem"
      }

      vault {
        policies      = ["plex", "issue-techunter-io"]
        change_mode   = "signal"
        change_signal = "SIGHUP"
      }

      service {
        port = "http"
        name = "plex"
        check {
          type     = "tcp"
          interval = "10s"
          timeout  = "2s"
        }
        tags = [
          "traefik.enable=true",
          "traefik.http.routers.${NOMAD_TASK_NAME}.entrypoints=websecure",
          "traefik.http.routers.${NOMAD_TASK_NAME}.rule=Host(`${NOMAD_TASK_NAME}.ix.techunter.io`)",
          "traefik.http.routers.${NOMAD_TASK_NAME}.tls=true"
        ]
      }

      resources {
        cpu    = 20000
        memory = 16284
      }
    }
  }
}

