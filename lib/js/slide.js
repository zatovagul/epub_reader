let color = "black";
let fontSize = 1;
let viewIsBook = true;
let page = 0;
let pageCount;

const initCss = () => `
  box-sizing: border-box;
  margin: 0;
  padding: 15px;
  background: transparent;
  color: ${color};
`;
const bookCss = () =>
  initCss() +
  `
  height: 100vh;
  column-width: 100vw;
  column-gap: 30px;
`;

const infoLog = (type) => {
  const info = {
    page,
    pageCount,
    scrollLeft: document.documentElement.scrollLeft,
    scrollWidth: document.body.scrollWidth,
    type,
  };
  const infoString = JSON.stringify(info);
  Print.postMessage(infoString);
  console.log(infoString);
};

document.body.style.cssText = bookCss();

async function renderBook() {
  // const changeMediaPath = (el, path) => {
  //   for (img of el.querySelectorAll(`img[src]`)) {
  //     console.log(img.src);
  //     img.src = path + img.src;
  //   }
  //   for (a of el.querySelectorAll(`a[href]`)) {
  //     a.href = path + a.href;
  //   }
  // };

  for (let index = 0; index < paths.length; index++) {
    const url = paths[index];
    const section = await fetch(url);
    const html = await section.text();
    const el = document.createElement("div");
    el.innerHTML = html;
    document.body.appendChild(el);

    // let { pathname } = new URL(url);
    // pathname = pathname.substring(0, pathname.lastIndexOf("/"))
    // changeMediaPath(el, pathname);
  }

  for (let index = 0; index < 3; index++) {
    const el = document.createElement("div");
    el.style.cssText = "display:block;min-width:100vw;min-height:100vh";
    document.body.appendChild(el);
  }
}

function setBookSettings() {
  const keys = { 37: 1, 38: 1, 39: 1, 40: 1 };
  let touchStart;
  let touchEnd;
  pageCount =
    Math.ceil(
      document.documentElement.scrollWidth /
        document.documentElement.clientWidth
    ) - 3;

  infoLog("init");

  function debounce(func, wait, immediate) {
    var timeout;
    return function () {
      var context = this,
        args = arguments;
      var later = function () {
        timeout = null;
        if (!immediate) func.apply(context, args);
      };
      var callNow = immediate && !timeout;
      clearTimeout(timeout);
      timeout = setTimeout(later, wait);
      if (callNow) func.apply(context, args);
    };
  }

  const slide = debounce((next) => {
    touchStart = undefined;
    touchEnd = undefined;

    if (next !== undefined) {
      page = next ? page + 1 : page - 1;
      window.scrollTo({
        left: document.documentElement.clientWidth * page,
        behavior: "smooth",
      });
      infoLog("pageChanged");
    }
  }, 100);

  function preventDefault(e) {
    let next;

    switch (e.type) {
      case "keydown":
        if (e.code === "ArrowRight") next = true;
        if (e.code === "ArrowLeft") next = false;
        break;
      case "touchmove":
        if (!touchStart) touchStart = e.touches[0].screenX;
        else {
          touchEnd = e.touches[0].screenX;
        }

        if (touchStart && touchEnd) {
          next = touchStart > touchEnd;
        }
        break;
      case "wheel":
        next = e.deltaX > 0;
        break;
    }

    if (!next && page !== 0) slide(next);
    else if (next && page < pageCount) slide(next);

    e.preventDefault();
  }

  function preventDefaultForScrollKeys(e) {
    if (keys[e.keyCode]) {
      preventDefault(e);
      return false;
    }
  }

  // modern Chrome requires { passive: false } when adding event
  var supportsPassive = false;
  try {
    window.addEventListener(
      "test",
      null,
      Object.defineProperty({}, "passive", {
        get: function () {
          supportsPassive = true;
        },
      })
    );
  } catch (e) {}

  const wheelOpt = supportsPassive ? { passive: false } : false;
  const wheelEvent =
    "onwheel" in document.createElement("div") ? "wheel" : "mousewheel";

  function disableScroll() {
    window.addEventListener("DOMMouseScroll", preventDefault, false); // older FF
    window.addEventListener(wheelEvent, preventDefault, wheelOpt); // modern desktop
    window.addEventListener("touchmove", preventDefault, wheelOpt); // mobile
    window.addEventListener("keydown", preventDefaultForScrollKeys, false);
  }

  function enableScroll() {
    window.removeEventListener("DOMMouseScroll", preventDefault, false);
    window.removeEventListener(wheelEvent, preventDefault, wheelOpt);
    window.removeEventListener("touchmove", preventDefault, wheelOpt);
    window.removeEventListener("keydown", preventDefaultForScrollKeys, false);
  }

  disableScroll();
  window.disableScroll = disableScroll;
  window.enableScroll = enableScroll;
}

function switchView() {
  viewIsBook = !viewIsBook;
  page = 0;
  console.log(viewIsBook ? "book" : "scroll");

  if (viewIsBook) {
    document.body.style.cssText = bookCss();
    disableScroll();
  } else {
    document.body.style.cssText = initCss();
    enableScroll();
  }
  infoLog("switchView");
}

function switchTheme() {
  color = color == "white" ? "black" : "white";
  document.body.style.color = color;
  infoLog("switchTheme");
}

function changeSize(increase = true, size = 1.2) {
  if (increase) fontSize *= size;
  else fontSize /= size;

  document.body.style.fontSize = fontSize + "rem";
  const h = [
    ...document.body.querySelectorAll("h1"),
    ...document.body.querySelectorAll("h2"),
    ...document.body.querySelectorAll("h3"),
    ...document.body.querySelectorAll("h4"),
    ...document.body.querySelectorAll("h5"),
    ...document.body.querySelectorAll("h6"),
  ];
  h.forEach((el) => (el.style.fontSize = fontSize));
  pageCount =
    Math.ceil(
      document.documentElement.scrollWidth /
        document.documentElement.clientWidth
    ) - 3;

  infoLog("changeSize");
}

window.addEventListener("load", async () => {
  await renderBook();
  setBookSettings();
});
