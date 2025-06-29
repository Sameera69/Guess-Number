let model;

async function loadModel() {
  if (!model) {
    model = await tf.loadLayersModel('https://storage.googleapis.com/tfjs-models/tfjs/mnist/model.json');
  }
}

async function predictDigit(imageDataArray) {
  await loadModel();

  const input = tf.tensor(imageDataArray, [1, 28, 28, 1]);
  const prediction = model.predict(input);
  const result = prediction.argMax(1).dataSync()[0];

  return result;
}
