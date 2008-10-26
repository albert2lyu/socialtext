(function($) {

var t = new Test.Visual();

t.plan(4);

if (jQuery.browser.msie)
    t.skipAll("Skipping this insanity on IE for now...");

t.runAsync([
    function() {
        t.login({}, t.nextStep());
    },

    function() {
        var widget = WID = t.setup_one_widget(
            {
                url: "/?action=add_widget;location=widgets/share/widgets/my_workspaces.xml",
                noPoll: true
            },
            t.nextStep()
        );
    },

    function() {
        t.scrollTo(150);

        t.is(
            t.$('div.widget.minimized').length,
            0,
            "Widgets start off non-minimized"
        );

        t.$('div.widgetHeader a.minimize:first').click();

        t.is(
            t.$('div.widget.minimized').length,
            1,
            "Clicking 'minimize' causes minimization"
        );

        t.iframe.contentWindow.location = '/index.cgi?';
        t.callNextStep(5000);
    },

    function() {
        t.is(
            t.$('div.widget.minimized').length,
            1,
            "Minimizing a widget should persist across reloads"
        );

        t.$('div.widgetHeader a.minimize:first').click();

        t.is(
            t.$('div.widget.minimized').length,
            0,
            "Clicking 'minimize' again stops minimization"
        );

        t.endAsync();
    }
]);

})(jQuery);
