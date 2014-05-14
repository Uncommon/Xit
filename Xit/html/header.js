function isCollapsed()
{
  return document.getElementById('committer').style.display == 'none'
}

function disclosure(clicked)
{
	var button = document.getElementById("triangle");
	var hidingIds = ['committer', 'sha', 'parents'];
	var newDisplay = 'none';
	var newImage = 'undisclosed.png';

	if (isCollapsed()) {
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
