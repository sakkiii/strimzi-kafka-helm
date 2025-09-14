# Kafka Version Upgrades Guide

This guide documents the proper sequence for upgrading Kafka versions in Strimzi-managed clusters, including rollback procedures and best practices.

## 📋 Prerequisites

- **Backup**: Always backup your Kafka data and configuration before upgrading
- **Testing**: Test the upgrade procedure in a non-production environment first
- **Monitoring**: Ensure monitoring is in place to track the upgrade progress
- **Maintenance Window**: Plan for downtime during the upgrade process

## 🔄 Upgrade Sequence

### Phase 1: Prepare Inter-Broker Protocol Version

**⚠️ CRITICAL**: Always set the inter-broker protocol version FIRST before upgrading Kafka binaries.

1. **Update the inter-broker protocol version** in your `values.yaml`:
   ```yaml
   kafkaCluster:
     config:
       # Set to the CURRENT Kafka version's protocol before upgrading
       inter.broker.protocol.version: "3.8"  # If upgrading FROM 3.8.x
       log.message.format.version: "3.8"     # Keep current format initially
   ```

2. **Apply the configuration change**:
   ```bash
   helm upgrade my-kafka . -f values-prod.yaml
   ```

3. **Wait for rolling restart** to complete:
   ```bash
   kubectl get pods -l strimzi.io/cluster=my-kafka -w
   ```

### Phase 2: Upgrade Kafka Version

4. **Update the Kafka version** in your `values.yaml`:
   ```yaml
   kafkaCluster:
     version: "3.9.0"  # New target version
     config:
       inter.broker.protocol.version: "3.8"  # Still old protocol
       log.message.format.version: "3.8"     # Still old format
   ```

5. **Apply the version upgrade**:
   ```bash
   helm upgrade my-kafka . -f values-prod.yaml
   ```

6. **Monitor the rolling upgrade**:
   ```bash
   # Watch pods restart with new version
   kubectl get pods -l strimzi.io/cluster=my-kafka -w
   
   # Check Kafka version in logs
   kubectl logs my-kafka-dual-role-0 -c kafka | grep "Kafka version"
   ```

### Phase 3: Update Protocol and Message Format

**⚠️ WARNING**: This step is irreversible. Ensure all brokers are running the new version successfully.

7. **Update protocol and message format versions**:
   ```yaml
   kafkaCluster:
     version: "3.9.0"
     config:
       inter.broker.protocol.version: "3.9"  # Now upgrade protocol
       log.message.format.version: "3.9"     # Now upgrade format
   ```

8. **Apply the final configuration**:
   ```bash
   helm upgrade my-kafka . -f values-prod.yaml
   ```

9. **Verify the upgrade**:
   ```bash
   # Check broker versions
   kubectl exec my-kafka-dual-role-0 -c kafka -- bin/kafka-broker-api-versions.sh \
     --bootstrap-server localhost:9092
   ```

## 🔙 Rollback Procedures

### Before Protocol/Format Upgrade (Phases 1-2)

If issues occur before updating protocol/format versions, you can rollback:

1. **Revert Kafka version**:
   ```yaml
   kafkaCluster:
     version: "3.8.0"  # Revert to previous version
     config:
       inter.broker.protocol.version: "3.8"
       log.message.format.version: "3.8"
   ```

2. **Apply rollback**:
   ```bash
   helm upgrade my-kafka . -f values-prod.yaml
   ```

### After Protocol/Format Upgrade (Phase 3)

**⚠️ CRITICAL**: Once protocol and message format are upgraded, rollback is NOT possible without data loss.

**Options if rollback is absolutely necessary**:
1. **Restore from backup** (recommended)
2. **Migrate data** to a new cluster with the old version
3. **Accept data loss** and start fresh

## 📊 Monitoring During Upgrades

### Key Metrics to Watch

```bash
# Broker availability
kubectl get pods -l strimzi.io/cluster=my-kafka

# Cluster health
kubectl exec my-kafka-dual-role-0 -c kafka -- bin/kafka-topics.sh \
  --bootstrap-server localhost:9092 --list

# Under-replicated partitions (should be 0)
kubectl exec my-kafka-dual-role-0 -c kafka -- bin/kafka-topics.sh \
  --bootstrap-server localhost:9092 --describe --under-replicated-partitions

# Consumer lag (if applicable)
kubectl exec my-kafka-dual-role-0 -c kafka -- bin/kafka-consumer-groups.sh \
  --bootstrap-server localhost:9092 --list
```

### Prometheus Metrics (if enabled)

Monitor these metrics during upgrades:
- `kafka_server_replicamanager_underreplicatedpartitions`
- `kafka_server_kafkaserver_brokerstate`
- `kafka_network_requestmetrics_totaltimems`

## 🚨 Troubleshooting

### Common Issues

#### 1. Broker Fails to Start After Upgrade

**Symptoms**: Pod in CrashLoopBackOff, logs show version compatibility errors

**Solution**:
```bash
# Check logs for specific error
kubectl logs my-kafka-dual-role-0 -c kafka

# Common fix: Ensure protocol version is compatible
# Revert to previous Kafka version if needed
```

#### 2. Under-Replicated Partitions

**Symptoms**: Topics show under-replicated partitions during upgrade

**Solution**:
```bash
# Wait for rolling restart to complete
kubectl get pods -l strimzi.io/cluster=my-kafka -w

# Check partition status
kubectl exec my-kafka-dual-role-0 -c kafka -- bin/kafka-topics.sh \
  --bootstrap-server localhost:9092 --describe --under-replicated-partitions

# If persistent, check broker logs for errors
```

#### 3. Client Compatibility Issues

**Symptoms**: Clients unable to connect after protocol upgrade

**Solution**:
- Ensure client libraries support the new protocol version
- Update client configurations if needed
- Consider gradual client migration

## 📝 Version Compatibility Matrix

| Kafka Version | Min Protocol Version | Max Protocol Version | Notes |
|---------------|---------------------|---------------------|-------|
| 3.8.x | 3.0 | 3.8 | Stable release |
| 3.9.x | 3.0 | 3.9 | Latest features |
| 4.0.x | 3.3 | 4.0 | Future release (KRaft only) |

## 🔧 Cruise Control Considerations

### Disable During Disruptive Operations

**⚠️ IMPORTANT**: Disable Cruise Control during upgrades to prevent interference:

```yaml
kafkaCluster:
  cruiseControl:
    enabled: false  # Disable during upgrade
```

**Re-enable after upgrade completion**:
```yaml
kafkaCluster:
  cruiseControl:
    enabled: true
```

### Rebalancing After Upgrades

After successful upgrade, consider rebalancing:

```yaml
# Apply KafkaRebalance resource
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaRebalance
metadata:
  name: post-upgrade-rebalance
  labels:
    strimzi.io/cluster: my-kafka
spec:
  mode: full
  goals:
    - RackAwareGoal
    - ReplicaCapacityGoal
    - DiskCapacityGoal
    - NetworkInboundCapacityGoal
    - NetworkOutboundCapacityGoal
    - CpuCapacityGoal
    - ReplicaDistributionGoal
    - PotentialNwOutGoal
    - DiskUsageDistributionGoal
    - NetworkInboundUsageDistributionGoal
    - NetworkOutboundUsageDistributionGoal
    - CpuUsageDistributionGoal
    - LeaderReplicaDistributionGoal
    - LeaderBytesInDistributionGoal
```

## 📚 References

- [Strimzi Upgrade Guide](https://strimzi.io/docs/operators/latest/deploying#assembly-upgrade-str)
- [Kafka Upgrade Documentation](https://kafka.apache.org/documentation/#upgrade)
- [KRaft Migration Guide](https://strimzi.io/docs/operators/latest/deploying#proc-migrating-clusters-kraft-str)
- [Cruise Control Goals](https://strimzi.io/docs/operators/latest/configuring#proc-cruise-control-goals-str)

## ✅ Pre-Upgrade Checklist

- [ ] Backup Kafka data and configuration
- [ ] Test upgrade in non-production environment
- [ ] Review [Kafka release notes](https://kafka.apache.org/downloads) for breaking changes
- [ ] Ensure monitoring is in place
- [ ] Schedule maintenance window
- [ ] Notify stakeholders
- [ ] Disable Cruise Control
- [ ] Verify client compatibility
- [ ] Prepare rollback plan
- [ ] Document current configuration

## ✅ Post-Upgrade Checklist

- [ ] Verify all brokers are running new version
- [ ] Check for under-replicated partitions
- [ ] Test client connectivity
- [ ] Monitor performance metrics
- [ ] Re-enable Cruise Control
- [ ] Consider post-upgrade rebalancing
- [ ] Update documentation
- [ ] Notify stakeholders of completion
