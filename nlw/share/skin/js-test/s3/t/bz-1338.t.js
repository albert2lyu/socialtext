(function($) {

var t = new Test.Visual();

t.plan(1);

t.checkRichTextSupport();

t.runAsync([
    function() {
        t.open_iframe(
            "/admin/index.cgi?action=weblog_display;category=bz_1358_really_long_"
                + Math.random() + Math.random() + Math.random() + Math.random()
                + Math.random() + Math.random() + Math.random() + Math.random(),
            t.nextStep()
        );
    },
            
    function() { 
        t.is(
            t.$('#st-editing-tools-edit').offset().top,
            t.$('#controlsRight').offset().top,
            "Overlong weblog names should truncate, not skewing controlsRight display"
        );
        t.endAsync();
    }
]);

})(jQuery);
