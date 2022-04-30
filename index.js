import { Game } from './game.js';

const config = {
  followNewTab: true,
  fps: 30,
  ffmpeg_Path: null,
  videoFrame: {
    width: 768,
    height: 1024,
  },
  aspectRatio: '9:16',
};

(async () => {
  for (let i = 0; i < 3; i++) {
    const game = await Game.fromConfig(config);
    await game.closeInstructionsModal();
    await game.wait();

    await game.startRecording('./video.mp4');

    const success = await game.autoPlay();
    await game.createShareText();

    await game.closePage();

    if (success) {
      process.exit(0);
    }
  }
})();
