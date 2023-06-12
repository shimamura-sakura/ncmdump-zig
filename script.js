'use strict';

const W = {
    mem(ptr, len) {
        return new Uint8Array(this.memory.buffer, ptr, len);
    }
};

const txtdec = new TextDecoder();
var lastInfo = null;
var lastPict = null;
var lastData = null;

WebAssembly.instantiateStreaming(fetch('ws/main.wasm'), {
    env: {
        setInfo(ptr, len) {
            console.log('setInfo', ptr, len);
            const info = txtdec.decode(W.mem(ptr, len)).replace(/^music:/, '');
            document.getElementById('info').textContent = info;
        },
        setPict(ptr, len) {
            console.log('setPict', ptr, len);
            if (lastPict) URL.revokeObjectURL(lastPict);
            const blob = new Blob([W.mem(ptr, len)]);
            const durl = URL.createObjectURL(blob);
            document.getElementById('image').src = lastPict = durl;
        },
        setData(ptr, len) {
            console.log('setData', ptr, len);
            if (lastData) URL.revokeObjectURL(lastData);
            const blob = new Blob([W.mem(ptr, len)]);
            const durl = URL.createObjectURL(blob);
            document.getElementById('audio').src = lastData = durl;
        },
        showErr(ptr, len) {
            console.log('showErr', ptr, len);
            const info = txtdec.decode(W.mem(ptr, len));
            document.getElementById('info').textContent = info;
        },
    }
}).then(function ({ instance: { exports: e }, module: m }) {
    W.memory = e.memory;
    W.jsFree = e.jsFree;
    W.jsAlloc = e.jsAlloc;
    W.process = e.process;
});

document.getElementById('file').onchange = function () {
    if (this.files.length === 0) return;
    const file = this.files[0];
    const addr = W.jsAlloc(file.size);
    if (addr === 0) {
        console.error('jsAlloc failed');
        return;
    }
    this.files[0].arrayBuffer().then(function (fileBuf) {
        W.mem(addr, file.size).set(new Uint8Array(fileBuf));
        W.process(addr, file.size);
    }).finally(() => {
        W.jsFree(addr, file.size);
    });
};