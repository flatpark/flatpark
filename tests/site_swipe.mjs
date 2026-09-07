import assert from 'node:assert/strict';
import { test } from 'node:test';
import { initSwipe } from '../site/src/scripts/swipe.js';

class Element extends EventTarget {
  dataset = {};
  classes = new Set();
  classList = {
    add: (...names) => names.forEach((name) => this.classes.add(name)),
    remove: (...names) => names.forEach((name) => this.classes.delete(name)),
    contains: (name) => this.classes.has(name),
  };
  style = { removeProperty(name) { delete this[name]; } };
  clientWidth = 400;
  inert = false;
  capture = null;
  animations = [];
  animate() {
    const { promise, resolve, reject } = Promise.withResolvers();
    const animation = { finished: promise, finish: resolve, cancel: () => reject(new Error('cancelled')) };
    this.animations.push(animation);
    return animation;
  }
  closest() { return null; }
  setPointerCapture(id) { this.capture = id; }
  hasPointerCapture(id) { return this.capture === id; }
  releasePointerCapture() { this.capture = null; }
}

function carousel(reducedMotion = true) {
  globalThis.Element = Element;
  globalThis.window = new EventTarget();
  window.matchMedia = () => ({ matches: reducedMotion });
  const viewport = new Element();
  const slides = Array.from({ length: 4 }, () => new Element());
  let current = 1;
  const show = (index) => {
    current = index;
    slides.forEach((slide, i) => {
      if (i === index) slide.classList.remove('hidden');
      else slide.classList.add('hidden');
    });
  };
  show(current);
  const swipe = initSwipe(viewport, () => slides, show);
  const pointer = (type, x, y = 100) => {
    const event = new Event(type, { cancelable: true });
    Object.assign(event, { pointerId: 1, isPrimary: true, button: 0, clientX: x, clientY: y });
    viewport.dispatchEvent(event);
  };
  const finish = async () => {
    slides.flatMap((slide) => slide.animations).forEach((animation) => animation.finish());
    await new Promise(setImmediate);
  };
  return { slides, pointer, swipe, finish, current: () => current };
}

for (const reducedMotion of [false, true]) {
  for (const direction of [-1, 1]) {
    const label = `direction ${direction}, reduced motion ${reducedMotion}`;
    test(`held drag reverses past its origin: ${label}`, async () => {
      const car = carousel(reducedMotion);
      car.pointer('pointerdown', 200);
      car.pointer('pointermove', 200 + direction * 120);
      car.pointer('pointermove', 200 - direction * 120);
      assert.equal(car.slides[1].style.transform, 'translateX(0px)');
      assert.ok(car.slides[1 + direction].classList.contains('hidden'), 'a third image must stay hidden');
      car.pointer('pointerup', 200 - direction * 120);
      await car.finish();
      assert.equal(car.current(), 1, 'reversing should return to the original image, not a third image');
      assert.equal(car.slides.filter((slide) => !slide.classList.contains('hidden')).length, 1);
    });

    test(`reversal first reported on release: ${label}`, async () => {
      const car = carousel(reducedMotion);
      car.pointer('pointerdown', 200);
      car.pointer('pointermove', 200 + direction * 120);
      car.pointer('pointerup', 200 - direction * 120);
      await car.finish();
      assert.equal(car.current(), 1);
    });

    test(`repeated reversals can still complete the initial swipe: ${label}`, async () => {
      const car = carousel(reducedMotion);
      car.pointer('pointerdown', 200);
      for (const distance of [120, -120, 80, -80, 60]) {
        car.pointer('pointermove', 200 + direction * distance);
      }
      car.pointer('pointerup', 200 + direction * 60);
      await car.finish();
      assert.equal(car.current(), 1 - direction);
    });

    test(`a new drag can swipe back: ${label}`, async () => {
      const car = carousel(reducedMotion);
      for (const step of [direction, -direction]) {
        car.pointer('pointerdown', 200);
        car.pointer('pointermove', 200 + step * 120);
        car.pointer('pointerup', 200 + step * 120);
        await car.finish();
        assert.equal(car.current(), step === direction ? 1 - direction : 1);
      }
    });

    test(`reversing below the swipe threshold cancels: ${label}`, async () => {
      const car = carousel(reducedMotion);
      car.pointer('pointerdown', 200);
      car.pointer('pointermove', 200 + direction * 120);
      car.pointer('pointermove', 200 + direction * 20);
      car.pointer('pointerup', 200 + direction * 20);
      await car.finish();
      assert.equal(car.current(), 1);
    });
  }
}
