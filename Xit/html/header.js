function isCollapsed()
{
  var committer = document.getElementById('committer')
  
  return (committer == null) || (committer.style.display == 'none')
}

function disclosure(clicked, forceDisclose)
{
	var button = document.getElementById("triangle");
	var hidingIds = ['committer', 'sha', 'parents'];
	var newDisplay = 'none';
	var newImage = 'undisclosed.png';

	if (forceCollapse || isCollapsed()) {
		newDisplay = 'block';
		newImage = 'disclosed.png'
	}
	for (var index in hidingIds) {
		document.getElementById(hidingIds[index]).style.display = newDisplay;
	}
	button.src = newImage;
  if (clicked)
    window.controller.headerToggled();
}
