# Helm Charts

This repository contains a collection of Helm charts for various applications, maintained by stevefan1999-personal.

## Prerequisites

- [Helm](https://helm.sh/docs/intro/install/) version 3.x or later.
- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/) configured to connect to your Kubernetes cluster.

## Getting Started

To start using the charts in this repository, you first need to add the repository to your Helm client.

### Add the Helm Repository

```bash
helm repo add stevefan1999-personal https://stevefan1999-personal.github.io/helm
helm repo update
```

## Available Charts

The following charts are available in this repository:

| Chart | Version | App Version | Description |
| :---- | :------ | :---------- | :---------- |
| [netbird](#netbird-chart) | 0.4.0 | 0.70.4 | A Helm chart for deploying NetBird, the open-source VPN that makes it easy to create secure private networks. |
| [netbird-combined](charts/netbird-combined) | 0.3.0 | 0.70.4 | A single-pod NetBird deployment with management, signal, relay, STUN, dashboard, and optional proxy containers. |
| [tuwunel](charts/tuwunel) | 0.1.0 | latest | A Helm chart for deploying the Tuwunel Matrix homeserver with OIDC, S3 media, ingress/TLS, and optional LiveKit MatrixRTC. |
| [zulip](charts/zulip) | 1.13.1 | 12.0-0 | A Kubernetes-native Zulip meta chart with role subcharts, operator-managed PostgreSQL/RabbitMQ, and in-chart cache services. |

---

## NetBird Chart

### Introduction

[NetBird](https://netbird.io/) is an open-source VPN platform that allows you to create secure private networks for your teams and services. It is built on top of WireGuard® to provide a fast and reliable VPN experience.

This Helm chart simplifies the deployment of NetBird on Kubernetes.

### Installing the Chart

To install the `netbird` chart, run the following command:

```bash
helm install my-release stevefan1999-personal/netbird
```

Replace `my-release` with your desired release name.

You can customize the installation by providing your own values in a YAML file:

```bash
helm install my-release stevefan1999-personal/netbird -f my-values.yaml
```

### Configuration

The following table lists the most commonly configured parameters for the NetBird chart and their default values.

| Parameter | Description | Default |
| :--- | :--- | :--- |
| `global.netbird.fqdn` | The Fully Qualified Domain Name for your NetBird instance. | `"netbird.example.com"` |
| `global.netbird.ingress.enabled` | Enable or disable Ingress for all NetBird components. | `true` |
| `global.netbird.ingress.className` | The IngressClass to use. | `"nginx"` |
| `global.netbird.ingress.tls.enabled` | Enable or disable TLS for Ingress. | `false` |
| `global.postgresql.external.enabled` | Use an external PostgreSQL database. | `true` |
| `global.postgresql.cnpg.enabled` | Deploy a CloudNativePG PostgreSQL cluster. | `false` |
| `dashboard.enabled` | Deploy the NetBird dashboard. | `true` |
| `management.enabled` | Deploy the NetBird management component. | `true` |
| `signal.enabled` | Deploy the NetBird signal component. | `true` |
| `relay.enabled` | Deploy the NetBird relay component. | `true` |

For a full list of configurable parameters, see the [`values.yaml`](charts/netbird/values.yaml) file.

### Dependencies

The `netbird` chart has the following dependencies:

| Chart | Repository | Condition |
| :--- | :--- | :--- |
| `cloudnative-pg` | `https://cloudnative-pg.github.io/charts` | `global.postgresql.cnpg.enabled` |
| `dashboard` | `file://charts/dashboard` | `dashboard.enabled` |
| `management` | `file://charts/management` | `management.enabled` |
| `signal` | `file://charts/signal` | `signal.enabled` |
| `relay` | `file://charts/relay` | `relay.enabled` |

---

## Tuwunel Chart

The `tuwunel` chart deploys a single Tuwunel Matrix homeserver with configurable OIDC/OAuth providers, ingress/TLS annotations for cert-manager, external S3-compatible media storage, an optional bundled LiveKit subchart for MatrixRTC/Element Call, and an optional bundled Cinny subchart for a lightweight web client.

Local k0s acceptance manifests are available under [`charts/tuwunel/acceptance`](charts/tuwunel/acceptance). The acceptance runner deploys Rauthy for OIDC, deploys the JuiceFS S3 gateway mock separately from the chart, enables the lightweight Cinny web client, uses a real `matrix-nio` Matrix client to exchange messages and media, restarts the data-bearing services, and verifies persistence.

---

## Zulip Chart

The `zulip` chart is a Kubernetes-native meta chart for Zulip. The parent chart owns shared infrastructure and configuration, while role subcharts render the public web/Django, Tornado, worker, and singleton runtimes as separate Kubernetes objects.

The chart can render CloudNativePG PostgreSQL and RabbitMQ Cluster Operator resources, or point Zulip at externally managed PostgreSQL, RabbitMQ, Redis, and Memcached services. Unit tests and CI values are available under [`charts/zulip/tests`](charts/zulip/tests) and [`charts/zulip/ci`](charts/zulip/ci).

Local k0s acceptance manifests are available under [`charts/zulip/acceptance`](charts/zulip/acceptance). The acceptance runner deploys a JuiceFS-backed S3 fixture, installs Zulip with object storage enabled, creates users/channels/messages through Zulip APIs, verifies Tornado event delivery, and checks post-restart persistence.

## Local Development

To test changes to the charts locally, you can use the `helm install --dry-run` command to render the templates without actually installing them. This is useful for debugging and verifying the output.

```bash
helm install my-release ./charts/netbird --dry-run > rendered-chart.yaml
```

You can also use a local Kubernetes cluster, such as [Kind](https://kind.sigs.k8s.io/) or [Minikube](https://minikube.sigs.k8s.io/docs/start/), to test the charts in a real environment.

## Contributing

Contributions are welcome! If you find any issues or have suggestions for improvements, please open an issue or submit a pull request to this repository.

## License

This repository and the charts within it are licensed under the MIT License. See the `LICENSE` file for more details.
