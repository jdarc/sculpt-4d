const path = require('path');
const HtmlWebpackPlugin = require("html-webpack-plugin");
const MiniCssExtractPlugin = require('mini-css-extract-plugin');
const { CleanWebpackPlugin } = require('clean-webpack-plugin');

module.exports = {
    entry: './src/js/main.js',
    output: {
        filename: '[fullhash].js',
        path: path.resolve(__dirname, 'dist')
    },
    plugins: [
        new CleanWebpackPlugin(),
        new MiniCssExtractPlugin({ filename: '[fullhash].css' }),
        new HtmlWebpackPlugin({
            template: "src/index.html",
            title: 'Sculpt Animate 4D',
            meta: { 'description': 'Realtime ray tracing of the iconic Sculpt Animate 4D crystal ball using WebGL' },
            minify: {
                removeComments: true,
                collapseWhitespace: true
            }
        })
    ],
    module: {
        rules: [{
            test: /\.css$/i,
            use: [MiniCssExtractPlugin.loader, 'css-loader'],
        }, {
            test: /\.glsl$/,
            use: ['webpack-glsl-loader']
        }]
    }
};
