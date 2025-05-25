alias krr="kubectl rollout restart"
alias kdm="data-mover"
alias kbb="busybox"

data-mover() {
  cat <<EOF | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: data-mover-$1-to-$2
spec:
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: data-mover
        image: busybox
        command: ["/bin/sh", "-c", "echo 'Starting copy...' && cp -rv /mnt/source/. /mnt/destination/ && echo 'Copy complete.'"]
        volumeMounts:
        - name: source
          mountPath: /mnt/source
        - name: destination
          mountPath: /mnt/destination
      volumes:
      - name: source
        persistentVolumeClaim:
          claimName: $1
      - name: destination
        persistentVolumeClaim:
          claimName: $2
EOF
}

busybox() {
  if [ -n "$1" ]; then
    kubectl run -it --rm busybox \
      --image=busybox \
      --restart=Never \
      --overrides='{
        "spec": {
          "containers": [{
            "name": "busybox",
            "image": "busybox",
            "stdin": true,
            "tty": true,
            "command": ["/bin/sh"],
            "volumeMounts": [{
              "name": "volume",
              "mountPath": "/volume"
            }]
          }],
          "volumes": [{
            "name": "volume",
            "persistentVolumeClaim": {
              "claimName": "'"$1"'"
            }
          }]
        }
      }'
  else
    kubectl run -it --rm busybox \
      --image=busybox \
      --restart=Never \
      -- /bin/sh
  fi
}