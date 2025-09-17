function meow() {
const wrapper = document.getElementById('spin-item-wrapper'); // Note the period (.)
const allDivs = document.querySelectorAll('.spin-item-inner'); // Selects the spinning divs

allDivs.forEach(item => {
  item.addEventListener('mouseenter', () => {
    console.log('meow');
    wrapper.getAnimations().forEach(y => {y.pause()})
    allDivs.forEach(div => {
    	div.getAnimations().forEach(y => {y.pause()})    
		});
  });
  item.addEventListener('mouseleave', () => {
    wrapper.getAnimations().forEach(y => {y.play()})
    allDivs.forEach(div => {
    	div.getAnimations().forEach(y => {y.play()})    
		});
  });
});
}

document.addEventListener("DOMContentLoaded", function() {
	main();
});

function genDemoLinks() {

}


// creates new spin-item element to be added to spin-items-wrapper
function makeLink(label, url) {
	const newSpinItem = document.createElement("span");
	newSpinItem.className = "spin-item"
	const newSpinItemInner = document.createElement("div")
	newSpinItemInner.className = "spin-item-inner"
	const hyperLink = document.createElement("a")
	hyperLink.src = url
	hyperLink.innerText = label

	newSpinItemInner.appendChild(hyperLink)
	newSpinItem.appendChild(newSpinItemInner)

	const wrapper = document.getElementById('spin-item-wrapper'); // Note the period (.)

	wrapper.appendChild(newSpinItem)
}

// calculates and applys rotations for all spin-items
function calculateRotations() {	
	const allDivs = document.querySelectorAll('.spin-item-inner'); // Selects the spinning divs
const wrapper = document.getElementById('spin-item-wrapper'); // Note the period (.)
const length = allDivs.length;

	  // Remove the animation
  wrapper.style.animation = 'none';

allDivs.forEach((item, i) => {
  // i starts from 0, so use i + 1 for 1-based index
  item.parentNode.style.setProperty('--amount-of-element', length);
  item.parentNode.style.setProperty('--nth-element', i + 1);
  item.firstElementChild.style.transform = `rotate(calc((360deg / ${length}) * ${i + 1} * -1))`;
	item.style.animation = 'none';
});
	meow()

  // Trigger a reflow (forces the browser to recognize the change)
  void wrapper.offsetWidth;

  // Re-add the animation (replace with your animation name, duration, etc.)
  wrapper.style.animation = 'spin 40s linear infinite';
	allDivs.forEach(item => {
		item.style.animation = 'counter-spin 40s linear infinite'
	})
}

function main() {
	meow();
}
