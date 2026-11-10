# Kubernetes
(( $+commands[kubectl] )) || return 0

export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config}"

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
alias kdel='kubectl delete'
(( $+commands[kubectx] )) && alias kc='kubectx'
(( $+commands[kubens] )) && alias kns='kubens'

# Pick pods with fzf and delete them after confirming.
kdelp() {
  local pods
  pods="$(kubectl get pods | fzf -m --header 'Select pods to delete' --header-lines=1 | awk '{print $1}')"
  [[ -z $pods ]] && { echo "No pods selected"; return 0; }
  read -q "?Delete ${#${(f)pods}} pod(s)? [y/N] " || { echo; return 0; }
  echo
  kubectl delete pod ${(f)pods}
}

# Pick a pod with fzf and follow its logs.
klp() {
  local pod
  pod="$(kubectl get pods | fzf --header-lines=1 --header 'Select pod to log' | awk '{print $1}')"
  [[ -z $pod ]] && { echo "No pod selected"; return 0; }
  kubectl logs -f --tail=50 "$pod"
}

# Same as klp, across all namespaces.
klns() {
  local selection
  selection="$(kubectl get pods -A | fzf --header-lines=1 --header 'Select pod (all namespaces)' | awk '{print $1, $2}')"
  [[ -z $selection ]] && { echo "No pod selected"; return 0; }
  kubectl logs -f --tail=50 -n "${selection%% *}" "${selection#* }"
}
