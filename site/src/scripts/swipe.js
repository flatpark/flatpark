/**
 * Drag slides with the pointer, then snap into place. Vertical scrolling and
 * pinch zoom stay native; controls outside the viewport are not draggable.
 * @param {HTMLElement} element
 * @param {() => HTMLElement[]} getSlides
 * @param {(index: number) => void} onChange
 */
export function initSwipe(element, getSlides, onChange) {
  /** @type {{ id: number, x: number, y: number, dragging: boolean } | null} */
  let gesture = null;
  /** @type {{ active: HTMLElement, neighbor: HTMLElement, width: number, dx: number, direction: number } | null} */
  let preview = null;
  /** @type {Animation[]} */
  let animations = [];
  /** @type {(() => void) | null} */
  let finishPending = null;
  let revision = 0;
  let suppressClick = false;
  element.dataset.swipe = '';

  const release = () => {
    const id = gesture?.id;
    gesture = null;
    element.classList.remove('is-dragging');
    if (id !== undefined && element.hasPointerCapture(id)) element.releasePointerCapture(id);
  };
  const hideNeighbor = () => {
    if (!preview) return;
    preview.neighbor.classList.add('hidden');
    preview.neighbor.classList.remove('swipe-neighbor');
    preview.neighbor.style.removeProperty('transform');
    preview.neighbor.inert = false;
  };
  const reset = () => {
    revision++;
    finishPending = null;
    release();
    animations.forEach((animation) => animation.cancel());
    animations = [];
    if (preview) {
      preview.active.style.removeProperty('transform');
      hideNeighbor();
      preview = null;
    }
  };
  /**
   * @param {number} dx
   * @param {number} direction
   * @param {HTMLElement} [target]
   */
  const drag = (dx, direction = preview?.direction ?? (dx < 0 ? 1 : -1), target) => {
    const slides = getSlides();
    const active = preview?.active ?? slides.find((slide) => !slide.classList.contains('hidden'));
    if (!active || slides.length < 2) return;
    const neighbor = target ?? slides[(slides.indexOf(active) + direction + slides.length) % slides.length];
    if (preview?.neighbor !== neighbor) hideNeighbor();
    const width = preview?.width ?? element.clientWidth;
    // Keep this gesture between its original pair of slides. Reversing past
    // the starting point returns to the active slide without revealing a third.
    dx = direction > 0 ? Math.max(-width, Math.min(0, dx)) : Math.max(0, Math.min(width, dx));
    preview = { active, neighbor, width, dx, direction };
    neighbor.classList.add('swipe-neighbor');
    neighbor.classList.remove('hidden');
    neighbor.inert = true;
    active.style.transform = `translateX(${dx}px)`;
    neighbor.style.transform = `translateX(${dx + direction * width}px)`;
  };
  /** @param {boolean} advance */
  const settle = (advance) => {
    release();
    if (!preview) return;
    const { active, neighbor, width, dx, direction } = preview;
    const finish = () => {
      reset();
      if (advance) onChange(getSlides().indexOf(neighbor));
    };
    finishPending = finish;
    if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
      finish();
      return;
    }
    const destination = advance ? -direction * width : 0;
    const options = { duration: 220, easing: 'cubic-bezier(0.2, 0.8, 0.2, 1)', fill: /** @type {FillMode} */ ('forwards') };
    animations = [
      active.animate([{ transform: `translateX(${dx}px)` }, { transform: `translateX(${destination}px)` }], options),
      neighbor.animate([{ transform: `translateX(${dx + direction * width}px)` }, { transform: `translateX(${destination + direction * width}px)` }], options),
    ];
    const currentRevision = ++revision;
    Promise.all(animations.map((animation) => animation.finished)).then(() => {
      if (revision === currentRevision) finish();
    }).catch(() => {}); // Another interaction or image removal cancelled the snap.
  };

  /**
   * Animate directly to a dot's slide, or follow an arrow's explicit direction.
   * @param {number} index
   * @param {number} [direction]
   */
  const goTo = (index, direction) => {
    const slides = getSlides();
    const active = preview?.active ?? slides.find((slide) => !slide.classList.contains('hidden'));
    reset();
    if (!active || slides.length < 2) return;
    index = ((index % slides.length) + slides.length) % slides.length;
    if (slides[index] === active) return;
    drag(0, direction ?? Math.sign(index - slides.indexOf(active)), slides[index]);
    settle(true);
  };
  /** @param {number} direction */
  const move = (direction) => {
    const slides = getSlides();
    // Repeated arrow presses advance from the pending destination, so a fast
    // second click is not lost while the first transition is still running.
    const current = animations.length ? preview?.neighbor : preview?.active;
    const active = current ?? slides.find((slide) => !slide.classList.contains('hidden'));
    if (active) goTo(slides.indexOf(active) + direction, direction);
  };

  element.addEventListener('pointerdown', (event) => {
    if (!event.isPrimary) {
      reset();
      return;
    }
    if (event.button !== 0) return;
    suppressClick = false;
    if (event.target instanceof Element && event.target.closest('button')) return;
    // A new drag starts from the previous swipe's destination, even when its
    // snap is still running. Cancelling it here would undo that first swipe.
    if (finishPending) finishPending();
    else reset();
    if (getSlides().length < 2) return;
    gesture = { id: event.pointerId, x: event.clientX, y: event.clientY, dragging: false };
  });
  element.addEventListener('pointermove', (event) => {
    if (!gesture || event.pointerId !== gesture.id) return;
    const dx = event.clientX - gesture.x;
    const dy = event.clientY - gesture.y;
    if (!gesture.dragging) {
      if (Math.max(Math.abs(dx), Math.abs(dy)) < 6) return;
      if (Math.abs(dy) >= Math.abs(dx)) {
        reset();
        return;
      }
      gesture.dragging = true;
      suppressClick = true;
      element.setPointerCapture(event.pointerId);
      element.classList.add('is-dragging');
    }
    event.preventDefault();
    drag(dx);
  });
  element.addEventListener('pointerup', (event) => {
    if (!gesture || event.pointerId !== gesture.id) return;
    const dx = event.clientX - gesture.x;
    const dy = event.clientY - gesture.y;
    if (gesture.dragging) drag(dx);
    settle(gesture.dragging && Math.abs(preview?.dx ?? 0) >= 40 && Math.abs(dx) > Math.abs(dy));
  });
  element.addEventListener('pointercancel', (event) => {
    if (event.pointerId === gesture?.id) settle(false);
  });
  element.addEventListener('lostpointercapture', (event) => {
    // Ignore implicit touch capture transferring from an image to the viewport.
    if (event.target === element && event.pointerId === gesture?.id) settle(false);
  });
  element.addEventListener('pointerleave', () => {
    if (gesture && !gesture.dragging) reset();
  });
  element.addEventListener('dragstart', (event) => event.preventDefault());
  element.addEventListener('click', (event) => {
    if (!suppressClick || event.detail === 0) return;
    suppressClick = false;
    event.preventDefault();
    event.stopImmediatePropagation();
  }, true);
  window.addEventListener('resize', reset);
  return { reset, goTo, move };
}
