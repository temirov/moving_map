const path = require('path');
const CssMinimizerPlugin = require('css-minimizer-webpack-plugin');
const MiniCssExtractPlugin = require('mini-css-extract-plugin');

module.exports = {
  entry: {
    'maplibre-gl-geocoder.min.js': './node_modules/@maplibre/maplibre-gl-geocoder/dist/maplibre-gl-geocoder.js', // JS entry
    'maplibre-gl-geocoder.min': [ // CSS entries
      './node_modules/@maplibre/maplibre-gl-geocoder/lib/index.css',
      './node_modules/@maplibre/maplibre-gl-geocoder/dist/maplibre-gl-geocoder.css'
    ],
  },
  output: {
    path: path.resolve(__dirname, 'public/dist'),
    filename: '[name].js', // JS output files will be named as [name].js
  },
  module: {
    rules: [
      {
        test: /\.js$/,
        exclude: /node_modules/,
        use: {
          loader: 'babel-loader',
          options: {
            presets: ['@babel/preset-env'],
          },
        },
      },
      {
        test: /\.css$/,
        use: [MiniCssExtractPlugin.loader, 'css-loader'], // Extract and process CSS files
        include: [
          path.resolve(__dirname, 'node_modules/@maplibre/maplibre-gl-geocoder/lib'),
          path.resolve(__dirname, 'node_modules/@maplibre/maplibre-gl-geocoder/dist')
        ],
      },
    ],
  },
  optimization: {
    minimize: true, // Minimize both JS and CSS
    minimizer: [
      '...', // Use default JS minimizer (Terser)
      new CssMinimizerPlugin(), // Minify CSS files
    ],
  },
  plugins: [
    new MiniCssExtractPlugin({
      filename: 'maplibre-gl-geocoder.min.css', // Name for the combined minified CSS output
    }),
  ],
  mode: 'production', // Set to production for minification
};
