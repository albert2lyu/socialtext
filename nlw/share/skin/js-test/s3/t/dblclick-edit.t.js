(function($) {

var t = new Test.Visual();

t.plan(5);

t.runAsync([
    function() {
        t.put_page({
            workspace: 'admin',
            page_name: "dblclick-edit",
            content: "dblclick-edit",
            callback: t.nextStep()
        });
    },

    function() {
        t.open_iframe("/admin/index.cgi?dblclick-edit", t.nextStep());
    },

    function() {
        t.scrollTo(100);

        t.ok(
            t.$("div#st-display-mode-container").is(":visible"),
            'Display is visible before edit'
        );

        t.ok(
            t.$("div#st-edit-mode-view").is(":hidden") ||
            ( t.$("div#st-edit-mode-view").size() == 0 ),
            'Editor is not visible'
        );

        t.$("div#st-page-content").dblclick();

        t.callNextStep(5000);
    },

    function() {
        t.ok(
            t.win.Wikiwyg,
            'Double click starts wikiwyg'
        );

        t.ok(
            t.$("div#st-display-mode-container").is(":hidden"),
            'Display is hidden after doubleclick to edit'
        );

        t.ok(
            t.$("div#st-edit-mode-view").is(":visible"),
            'Editor is now visible'
        );

        t.endAsync();
    }
]);

})(jQuery);
