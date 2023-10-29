#!/usr/bin/env bash

# make sure we are in the repository rood directory
cd "$(dirname "$0")/.." || exit 1

die() {
  echo
  echo "$*"
  echo
  exit 1
} >&2

function init() {
  terraform init --reconfigure

  if [ ! $? -eq 0 ]; then
    die "Init did not succeeded"
  fi
}

function apply() {
  TF_PLAN=terraform.plan

  terraform plan -var-file=./conf/main.tfvars -detailed-exitcode -out=$TF_PLAN
  plan_exit_code=$?

  if [[ $DRY_RUN == "true" ]]; then
    echo -e "${BIPurple}Dry-run completed with exit code:${NC} $plan_exit_code"
    exit 0
  fi

  terraform apply $TF_PLAN
}

function destroy() {
  init
  terraform destroy --auto-approve
}

function recreate() {
  destroy
  echo "Backoff (20s)..."
  sleep 20s
  apply
}

BIPurple='\033[1;95m'
NC='\033[0m'

AVAILABLE_ACTIONS="Available actions: [apply, enabled, disabled]"

POSITIONAL_ARGS=()

while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
  -a | --action)
    ACTION=$2
    shift
    shift
    ;;
  --dry-run)
    DRY_RUN=true
    shift # past argument
    ;;
  -*)
    echo "Unknown option $1"
    exit 1
    ;;
  *)
    echo "Hello $1"
    POSITIONAL_ARGS+=("$1") # save positional arg
    shift                   # past argument
    ;;
  esac
done

set -- "${POSITIONAL_ARGS[@]}" # restore positional parameters

if [[ -z "$ACTION" ]]; then
  echo "Action not specified. $AVAILABLE_ACTIONS"
  exit 1
fi

if [[ "$ACTION" = "enabled" && "$GITHUB_COMMIT_MESSAGE" == *"action: apply"* ]]; then
  echo "Creating infrastructure"
  apply
elif [[ "$ACTION" = "disabled" || "$GITHUB_COMMIT_MESSAGE" == *"action: destroy"* ]]; then
  echo "Destroying infrastructure"
  destroy
elif [[ "$ACTION" = "enabled" && "$GITHUB_COMMIT_MESSAGE" == *"action: re-create"* ]]; then
  echo "Re-creating infrastructure"
  recreate
elif [[ "$ACTION" = "enabled" || "$ACTION" = "disabled" ]]; then
  echo "Unknown commit message action provided: $GITHUB_COMMIT_MESSAGE. Available actions: [action: apply, action: destroy, action: re-create]"
else
  echo "Unknown action provided: $ACTION. Available actions: $AVAILABLE_ACTIONS"
fi
