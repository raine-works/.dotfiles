# shellcheck shell=bash
# Kubernetes — kubectl, kubectx, kubens aliases
command -v kubectl >/dev/null 2>&1 || return 0

export KUBECONFIG=~/.kube/config

alias k='kubectl'
alias ka='kubectl apply -f'
alias ke='kubectl exec -it'
alias kg='kubectl get'
alias kd='kubectl describe'
alias kgpo='kubectl get pods'
alias kgd='kubectl get deployments'
alias kgs='kubectl get svc'
alias kgpow='kubectl get pods -o wide'
alias kl='kubectl logs -f --tail=50'
alias kdel="kubectl delete"

kdelp() {
    local pods confirm
    pods="$(kubectl get pods | fzf -m --header "Select Pods to Delete" --header-lines=1 | awk '{print $1}')"

    if [ -z "$pods" ]; then
        echo "No pods selected"
        return 0
    fi

    if [ -r /dev/tty ] && [ -w /dev/tty ]; then
        read -rp "Delete selected pods? [y/N]: " confirm </dev/tty
    else
        confirm="n"
    fi

    case "$confirm" in
        y | Y | yes | YES) ;;
        *)
            echo "Aborted"
            return 0
            ;;
    esac

    printf "%s\n" "$pods" | xargs kubectl delete pod
}

klp() {
    local pod
    pod="$(kubectl get pods | fzf --header-lines=1 --header "Select Pod to Log" | awk 'NR==1 {print $1}')"

    if [ -z "$pod" ]; then
        echo "No pod selected"
        return 0
    fi

    kubectl logs -f --tail=50 "$pod"
}

klns() {
    local selection namespace pod
    selection="$(kubectl get pods -A | fzf --header-lines=1 --header "Select Pod (All Namespaces)" | awk 'NR==1 {print $1" "$2}')"

    if [ -z "$selection" ]; then
        echo "No pod selected"
        return 0
    fi

    namespace="${selection%% *}"
    pod="${selection#* }"

    kubectl logs -f --tail=50 -n "$namespace" "$pod"
}

command -v kubectx >/dev/null 2>&1 && alias kc='kubectx'
command -v kubens >/dev/null 2>&1 && alias kns='kubens'
