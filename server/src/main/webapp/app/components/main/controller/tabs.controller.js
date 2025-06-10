// Localization completed
angular.module('headwind-kiosk')
    .controller('TabController', ['$scope', '$rootScope', '$timeout', 'userService', 'authService', 'openTab', '$state',
                                           'pluginService', 'localization', 'hintService', function ($scope, $rootScope, $timeout, userService, authService, openTab, $state,
                                           pluginService, localization, hintService) {

        $scope.localization = localization;

        var routes = {
            SUMMARY: 'summary',
            DEVICES: 'main',
            APPS: 'applications',
            CONFS: 'configurations',
            FILES: 'files',
            DESIGN: 'designSettings',
            COMMON: 'commonSettings',
            USERS: 'users',
            ROLES: 'roles',
            GROUPS: 'groups',
            LANG: 'langSettings',
            HINTS: 'hints',
            PLUGINS: 'pluginSettings'
        };

        var loadData = function () {
            pluginService.getAvailablePlugins(function (response) {
                if (response.status === 'OK') {
                    if (response.data) {
                        // Plugins available for Functions tab
                        $scope.functionsPlugins = response.data.filter(function (plugin) {
                            return plugin.functionsViewTemplate !== undefined && plugin.functionsViewTemplate !== null;
                        });
                        $scope.functionsPlugins.forEach(function (plugin) {
                            let ID = 'plugin-' + plugin.identifier;
                            routes[ID] = ID;
                        });

                        // Plugins available for Settings tab
                        $scope.settingsPlugins = response.data.filter(function (plugin) {
                            return plugin.settingsViewTemplate !== undefined && plugin.settingsViewTemplate !== null;
                        });
                        $scope.settingsPlugins.forEach(function (plugin) {
                            let ID = 'plugin-settings-' + plugin.identifier;
                            routes[ID] = ID;
                        });
                    }
                } else {
                    $scope.functionsPlugins = [];
                    $scope.settingsPlugins = [];
                }
            });
        };

        $scope.currentUser = {};

        $scope.hasPermission = authService.hasPermission;
        $scope.canManageRoles = function() {
            return authService.isSingleCustomer() || authService.isSuperAdmin();
        };

        $scope.activeTab = openTab;

        $scope.act = {};
        $scope.act[openTab] = true;

        $scope.functionsPlugins = [];
        $scope.settingsPlugins = [];

        $scope.isSettingsTabActive = function() {
            // Ensure $scope.activeTab, $scope.settingsPlugins are available
            // It's assumed settingsPlugins might be fetched or initialized elsewhere in this controller or a service
            // and made available on $scope.
            return ['DESIGN', 'COMMON', 'USERS', 'ROLES', 'GROUPS', 'LANG', 'HINTS', 'PLUGINS'].includes($scope.activeTab) ||
                ($scope.settingsPlugins || []).some(p => $scope.activeTab === 'plugin-settings-' + p.identifier);
        };

        $scope.isPluginsTabActive = function() {
            // Ensure $scope.activeTab, $scope.functionsPlugins are available
            // It's assumed functionsPlugins might be fetched or initialized elsewhere in this controller or a service
            // and made available on $scope.
            return ($scope.functionsPlugins || []).some(p => $scope.activeTab === 'plugin-' + p.identifier);
        };

        $scope.openTab = function (tabName) {
            if (tabName === $scope.activeTab) {
                return;
            }
            if (routes[tabName]) {
                $state.transitionTo(routes[tabName]);
            }
        };

        var listener = $scope.$on('aero_PLUGINS_UPDATED', loadData);
        $scope.$on('$destroy', listener);

        userService.getCurrent(function (response) {
            if (response.data) {
                $scope.currentUser = response.data;
            }
        });

        // hintService start is fired by the controllers themselves after they are loaded all required content
//        $timeout(function () {
//            hintService.onStateChangeSuccess();
//        }, 100);

        loadData();
}]);
