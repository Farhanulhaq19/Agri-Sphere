// Text from users can contain line breaks that fake extra log lines; keep it on one line and short.
const safe = (v) => String(v === undefined || v === null ? '' : v).replace(/[\r\n\t\u2028\u2029]+/g, ' ').slice(0, 300);
module.exports = { safe };
