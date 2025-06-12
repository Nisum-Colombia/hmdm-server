// Localization completed
angular.module('headwind-kiosk')
    .controller('SummaryTabController', function ($scope, localization, summaryService) {
        $scope.stat = undefined; // This might be legacy, consider removing if not used by new logic
        $scope.errorMessage = undefined;
        $scope.summaryErrorMessage = undefined;
        $scope.logsErrorMessage = undefined;

        // Date pickers
        $scope.dateTo = new Date();
        $scope.dateFrom = new Date();
        $scope.dateFrom.setDate($scope.dateTo.getDate() - 30);

        // Summary data
        $scope.enrollmentData = []; // This might need to be re-evaluated based on new summary requirements
        $scope.enrollmentLabels = [ // These labels might be outdated with daily data
            localization.localize('summary.devices.enrolled.earlier'), // Consider if this concept is still relevant
            localization.localize('summary.devices.enrolled.period') // Changed from 'monthly'
        ];
        $scope.enrollmentColors = ['#DCDCDC', '#97BBCD'];


        $scope.statusLabels = [
            localization.localize('summary.devices.offline'),
            localization.localize('summary.devices.idle'),
            localization.localize('summary.devices.active')
        ];
        $scope.statusColors = ['#F7464A', '#FDB45C', '#46BFBD'];
        $scope.statusData = [0, 0, 0];


        $scope.installLabels = [
            localization.localize('summary.devices.installation.failed'),
            localization.localize('summary.devices.version.mismatch'),
            localization.localize('summary.devices.installation.completed')
        ];
        $scope.installColors = $scope.statusColors;
        $scope.installData = [0, 0, 0];

        // Daily enrollment chart
        $scope.dailyEnrollLabels = [];
        $scope.dailyEnrollData = [];
        $scope.dailyEnrollColors = ['#97BBCD']; // Default color, can be an array if chart supports multiple series for daily

        // Config-based charts
        $scope.statusByConfigSeries = [
            localization.localize('summary.devices.offline'),
            localization.localize('summary.devices.idle'),
            localization.localize('summary.devices.active')
        ];
        $scope.statusByConfigColors = ['#F7464A', '#FDB45C', '#46BFBD'];
        $scope.statusByConfigLabels = [];
        $scope.statusByConfigData = [];

        $scope.installByConfigSeries = [
            localization.localize('summary.devices.installation.failed'),
            localization.localize('summary.devices.version.mismatch'),
            localization.localize('summary.devices.installation.completed')
        ];
        $scope.installByConfigColors = $scope.statusByConfigColors;
        $scope.installByConfigLabels = [];
        $scope.installByConfigData = [];

        // New summary fields
        $scope.averageDevicesPerCustomer = 0;
        $scope.enrolledCustomersCount = 0;
        $scope.devicesEnrolledInPeriod = 0; // To store count of devices enrolled in selected period

        // Loading flags
        $scope.loadingSummary = false;
        $scope.loadingLogs = false;

        var fetchSummaryData = function () {
            $scope.loadingSummary = true;
            $scope.summaryErrorMessage = undefined;

            summaryService.getDeviceStat({
                dateFrom: $scope.dateFrom.getTime(),
                dateTo: $scope.dateTo.getTime()
            }, function (response) {
                if (response.data) {
                    // The 'devicesEnrolledEarlier' concept might need to be rethought with date pickers
                    // For now, devicesEnrolled in response.data refers to the count within the period
                    $scope.devicesEnrolledInPeriod = response.data.devicesEnrolled || 0;

                    // Example: if you still want a chart for total vs period:
                    // var devicesEnrolledEarlier = response.data.devicesTotal - $scope.devicesEnrolledInPeriod;
                    // if (devicesEnrolledEarlier < 0) devicesEnrolledEarlier = 0;
                    // $scope.enrollmentData = [devicesEnrolledEarlier, $scope.devicesEnrolledInPeriod];
                    // For now, let's assume enrollmentData/Labels are not the primary focus or will be removed for daily chart

                    $scope.statusData = [0, 0, 0];
                    if (response.data.statusSummary) {
                        response.data.statusSummary.forEach(function (item) {
                            if (item.stringAttr === 'red') $scope.statusData[0] = item.number;
                            else if (item.stringAttr === 'yellow') $scope.statusData[1] = item.number;
                            else if (item.stringAttr === 'green') $scope.statusData[2] = item.number;
                        });
                    }

                    $scope.installData = [0, 0, 0];
                    if (response.data.installSummary) {
                        response.data.installSummary.forEach(function (item) {
                            if (item.stringAttr === 'FAILURE') $scope.installData[0] = item.number;
                            else if (item.stringAttr === 'VERSION_MISMATCH') $scope.installData[1] = item.number;
                            else if (item.stringAttr === 'SUCCESS') $scope.installData[2] = item.number;
                        });
                    }

                    $scope.statusByConfigLabels = response.data.topConfigs || [];
                    $scope.statusByConfigData = [];
                    $scope.statusByConfigData.push(response.data.statusOfflineByConfig || []);
                    $scope.statusByConfigData.push(response.data.statusIdleByConfig || []);
                    $scope.statusByConfigData.push(response.data.statusOnlineByConfig || []);

                    $scope.installByConfigLabels = $scope.statusByConfigLabels;
                    $scope.installByConfigData = [];
                    $scope.installByConfigData.push(response.data.appFailureByConfig || []);
                    $scope.installByConfigData.push(response.data.appMismatchByConfig || []);
                    $scope.installByConfigData.push(response.data.appSuccessByConfig || []);

                    // Daily enrollment data
                    $scope.dailyEnrollLabels = [];
                    $scope.dailyEnrollData = [];
                    if (response.data.devicesEnrolledDaily) {
                        response.data.devicesEnrolledDaily.forEach(function (item) {
                            $scope.dailyEnrollLabels.push(item.stringAttr); // Assuming stringAttr is date
                            $scope.dailyEnrollData.push(item.number);
                        });
                    }

                    // New summary fields
                    $scope.averageDevicesPerCustomer = response.data.averageDevicesPerCustomer || 0;
                    $scope.enrolledCustomersCount = response.data.enrolledCustomersCount || 0;

                } else {
                    $scope.summaryErrorMessage = localization.localize('error.invalid.response');
                }
                $scope.loadingSummary = false;
            }, function (error) {
                $scope.summaryErrorMessage = localization.localize('error.internal.server') + (error.data.message ? ': ' + error.data.message : '');
                $scope.loadingSummary = false;
            });
        };
       

        $scope.fetchData = function () {
            fetchSummaryData();
        };

        $scope.pageChanged = function (newPage) {
        };

        // Watch for date changes to refetch data
        // Using simple watch, could be optimized with debounce or specific change handlers for buttons
        $scope.$watchGroup(['dateFrom', 'dateTo'], function(newValues, oldValues) {
            if (newValues[0] !== oldValues[0] || newValues[1] !== oldValues[1]) {
                // Reset to first page for logs when date range changes                
                $scope.fetchData();
            }
        });

        // Initial load
        $scope.fetchData();
    });