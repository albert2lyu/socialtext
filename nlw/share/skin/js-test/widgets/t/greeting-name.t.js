(function($) {

var t = new Test.Visual();

t.plan(1);

t.beginAsync();

part1 = function() {
    t.ts = (new Date()).getTime();
    t.username = 'user' + t.ts + '@example.com',
    t.email_address = 'email' + t.ts + '@example.com',

    t.create_user({
        username: t.username,
        email_address: t.email_address,
        password: 'd3vnu11l',
        callback: part2
    });
}

part2 = function() {
    t.login({
        'username': t.username,
        'password': 'd3vnu11l',
        'callback': part3
    });
}

part3 = function() {
    t.open_iframe("/");
};

t.runTests = function() {
    var username = t.$("div.welcome span").text()
        .replace(/^\s*Hello,\s*(.*)\s*$/, '$1');
    t.is(username, 'user' + t.ts,
        'User name is correct (user' + t.ts + ') when user has no name'
    );
    t.endAsync();
};

t.login({callback: part1});


})(jQuery);
