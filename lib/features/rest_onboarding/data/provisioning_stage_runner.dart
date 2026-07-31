import '../domain/onboarding_provisioning.dart';

typedef ProvisioningStageAction = Future<void> Function();
typedef ProvisioningFailureInjector =
    void Function(RestaurantProvisioningStage stage);
typedef ProvisioningStageObserver =
    void Function(RestaurantProvisioningStage stage);

const provisioningPreparationStages = <RestaurantProvisioningStage>[
  RestaurantProvisioningStage.branch,
  RestaurantProvisioningStage.qr,
  RestaurantProvisioningStage.floors,
  RestaurantProvisioningStage.tables,
  RestaurantProvisioningStage.settings,
  RestaurantProvisioningStage.admin,
];

Future<void> runAtomicProvisioningStages({
  required Map<RestaurantProvisioningStage, ProvisioningStageAction> actions,
  required ProvisioningStageAction commit,
  ProvisioningFailureInjector? failureInjector,
  ProvisioningStageObserver? onStageStarted,
  ProvisioningStageObserver? onStagePrepared,
}) async {
  for (final stage in provisioningPreparationStages) {
    final action = actions[stage];
    if (action == null) {
      throw StateError('Missing provisioning action for ${stage.logName}.');
    }
    onStageStarted?.call(stage);
    await action();
    onStagePrepared?.call(stage);
    failureInjector?.call(stage);
  }

  onStageStarted?.call(RestaurantProvisioningStage.commit);
  await commit();
  onStagePrepared?.call(RestaurantProvisioningStage.commit);
}
