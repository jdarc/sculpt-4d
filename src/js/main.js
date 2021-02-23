import '../css/main.css';

import vertexShaderSource from "../shaders/vertex.glsl";
import fragmentShaderSource from "../shaders/fragment.glsl";

const compileShader = (gl, shaderSource, shaderType) => {
    const shader = gl.createShader(shaderType);
    gl.shaderSource(shader, shaderSource);
    gl.compileShader(shader);
    if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) {
        throw "shader compilation failed:" + gl.getShaderInfoLog(shader);
    }
    return shader;
};

const createProgram = (gl, vertexSource, fragmentSource) => {
    const program = gl.createProgram();
    gl.attachShader(program, compileShader(gl, vertexSource, gl.VERTEX_SHADER));
    gl.attachShader(program, compileShader(gl, fragmentSource, gl.FRAGMENT_SHADER));
    gl.linkProgram(program);
    if (!gl.getProgramParameter(program, gl.LINK_STATUS)) {
        throw ("program linking failed:" + gl.getProgramInfoLog(program));
    }
    return program;
};

const computeMatrix = (eye = [ 0, 1, 1 ], center = [ 0, 0, 0 ], up = [ 0, 1, 0 ], fov = Math.PI / 4.0, aspectRatio = 1.0, near = 1.0, far = 1000.0, matrix = new Float32Array(16)) => {
    const tan = Math.tan(fov / 2);
    const z0 = eye[0] - center[0];
    const z1 = eye[1] - center[1];
    const z2 = eye[2] - center[2];
    const lz = 1 / Math.sqrt(z0 * z0 + z1 * z1 + z2 * z2);
    const x0 = up[1] * z2 - up[2] * z1;
    const x1 = up[2] * z0 - up[0] * z2;
    const x2 = up[0] * z1 - up[1] * z0;
    const lx = tan * aspectRatio / Math.sqrt(x0 * x0 + x1 * x1 + x2 * x2);
    const y0 = z1 * x2 - z2 * x1;
    const y1 = z2 * x0 - z0 * x2;
    const y2 = z0 * x1 - z1 * x0;
    const ly = tan / Math.sqrt(y0 * y0 + y1 * y1 + y2 * y2);
    matrix[0] = x0 * lx;
    matrix[1] = x1 * lx;
    matrix[2] = x2 * lx;
    matrix[3] = 0;
    matrix[4] = y0 * ly;
    matrix[5] = y1 * ly;
    matrix[6] = y2 * ly;
    matrix[7] = 0;
    matrix[8] = z0 * lz;
    matrix[9] = z1 * lz;
    matrix[10] = z2 * lz;
    matrix[11] = 0;
    matrix[12] = eye[0];
    matrix[13] = eye[1];
    matrix[14] = eye[2];
    matrix[15] = 1;
};

window.addEventListener("load", () => {
    const canvas = document.querySelector('canvas');
    canvas.width = 1024;
    canvas.height = 768;

    const gl = canvas.getContext('webgl2', { alpha: false, stencil: false, depth: false });
    const program = createProgram(gl, vertexShaderSource, fragmentShaderSource);
    program.uniforms = {
        time: gl.getUniformLocation(program, "uTime"),
        resolution: gl.getUniformLocation(program, "uResolution"),
        cameraMatrix: gl.getUniformLocation(program, "uCameraMatrix")
    }
    program.attributes = {
        position: gl.getAttribLocation(program, "aPosition")
    };
    gl.enableVertexAttribArray(program.attributes.position);

    const vertices = new Float32Array([ -1.0, -1.0, 1.0, -1.0, 1.0, 1.0, 1.0, 1.0, -1.0, 1.0, -1.0, -1.0 ]);
    const vertexBuffer = gl.createBuffer();
    gl.bindBuffer(gl.ARRAY_BUFFER, vertexBuffer);
    gl.bufferData(gl.ARRAY_BUFFER, vertices, gl.STATIC_DRAW);
    gl.vertexAttribPointer(program.attributes.position, 2, gl.FLOAT, false, 0, 0);

    gl.useProgram(program);

    const camera = new Float32Array(16);
    const render = (timestamp) => {
        let angle = timestamp / 2000.0;
        let cos = Math.cos(angle);
        let sin = Math.sin(angle);
        let x = cos + sin * 4;
        let z =-sin + cos * 4;

        computeMatrix([ x, 2.8, z ], [ 0, 0.9, 0 ], [ 0, 1, 0 ], Math.PI / 5.0, canvas.width / canvas.height, 1.0, 1000.0, camera);
        gl.uniform1i(program.uniforms.time, timestamp);
        gl.uniform2f(program.uniforms.resolution, canvas.width, canvas.height);
        gl.uniformMatrix4fv(program.uniforms.cameraMatrix, gl.FALSE, camera);
        gl.drawArrays(gl.TRIANGLES, 0, 6);

        window.requestAnimationFrame(render);
    };

    window.requestAnimationFrame(render)
});
