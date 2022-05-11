import puppeteer from 'puppeteer';
import { PuppeteerScreenRecorder } from 'puppeteer-screen-recorder';
import fs from 'fs';

const cookies = [
  { name: 'purr-pref-agent', value: '<Go', domain: 'www.nytimes.com' },
  { name: 'nyt-purr', value: 'cfhheaihhudl', domain: 'www.nytimes.com' },
];

export class Game {
  constructor({ page, recorder, browser, config: { useSortedList } }) {
    this.browser = browser;
    this.page = page;
    this.recorder = recorder;
    const list = useSortedList ? 'words.sorted.json' : 'words.json';
    this.words = JSON.parse(fs.readFileSync(list, 'utf8'));
    this.has = [];

    this.useSortedList = useSortedList;
  }

  static async fromConfig(config) {
    const browser = await puppeteer.launch({
      defaultViewport: null,
      defaultViewport: config.videoFrame,
      // headless: false,
      args: [
        `--window-size=${config.videoFrame.width},${config.videoFrame.height}`,
      ],
    });
    const page = await browser.newPage();
    page.setCookie(...cookies);
    await page.emulateMediaFeatures([
      { name: 'prefers-color-scheme', value: 'dark' },
    ]);

    const recorder = new PuppeteerScreenRecorder(page, config);
    await page.goto('https://www.nytimes.com/games/wordle/index.html');

    const game = new Game({ page, recorder, browser, config });
    await game.syncState();

    return game;
  }

  async startRecording(savePath) {
    await this.recorder.start(savePath);
  }

  async closePage() {
    await this.recorder.stop();
    await this.browser.close();
  }

  async closeInstructionsModal() {
    const close = await this.page.evaluateHandle(
      `document.querySelector("body > game-app").shadowRoot.querySelector("#game > game-modal").shadowRoot.querySelector("div > div > div > game-icon")`
    );
    await close.click();
  }

  async wait(n = 1000) {
    await this.page.waitForTimeout(n);
  }

  async guess(
    word = this.words[Math.floor(Math.random() * this.words.length)]
  ) {
    if (this.state.gameStatus !== 'IN_PROGRESS') return;

    console.log(`Guessing: ${word}`);

    for (let i = 0; i < word.length; i++) {
      await this.page.keyboard.press(word[i]);
      await this.wait(150);
    }
    await this.page.keyboard.press('Enter');
    await this.syncState();
    await this.wait(2750);
  }

  async syncState() {
    const raw = await this.page.evaluate(() =>
      localStorage.getItem('nyt-wordle-state')
    );
    this.state = JSON.parse(raw);
  }

  async autoPlay() {
    console.log(`Words: ${this.words.length}`);
    const word =
      this.useSortedList && this.state.rowIndex ? this.words[0] : undefined;
    await this.guess(word);

    const { state } = this;
    const guess = state.boardState[state.rowIndex - 1];
    const evaluation = state.evaluations[state.rowIndex - 1];

    evaluation.forEach((result, letterIndex) => {
      const letter = guess[letterIndex];

      if (result !== 'absent' && !this.has.includes(letter)) {
        this.has.push(letter);
      }

      if (result === 'absent' && !this.has.includes(letter)) {
        const repeatOk = guess
          .split('')
          .find(
            (l, i) =>
              l === letter && i !== letterIndex && evaluation[i] !== 'absent'
          );
        if (!repeatOk) {
          this.words = this.words.filter((w) => !w.includes(letter));
        }
      }

      if (result === 'present') {
        this.words = this.words.filter((w) => w.includes(letter));
      }

      this.words = this.words.filter(
        (w) => (result === 'correct') === (w[letterIndex] === letter)
      );
    });

    if (state.gameStatus === 'IN_PROGRESS') {
      return await this.autoPlay();
    } else {
      return state.gameStatus === 'WIN';
    }
  }

  async createShareText() {
    const since = new Date(2021, 5, 19, 0, 0, 0, 0);
    const diff = new Date().setHours(0, 0, 0, 0) - since.setHours(0, 0, 0, 0);
    const day = Math.round(diff / 864e5);

    const guesses = this.state.gameStatus === 'WIN' ? this.state.rowIndex : 'X';
    const text = `Wordle ${day} ${guesses}/6`;

    const emojis = this.state.evaluations
      .filter((line) => !!line)
      .map((line) =>
        line
          .map(
            (ev) =>
              ({
                correct: '🟩',
                absent: '⬜', // ⬛
                present: '🟨',
              }[ev])
          )
          .join('')
      )
      .join('\n');

    fs.writeFileSync('share.txt', `${text}\n\n${emojis}`);
  }
}
