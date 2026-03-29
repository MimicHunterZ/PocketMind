bool shouldInitializeWorkmanager(String platformName) {
  return platformName == 'android' || platformName == 'ios';
}
