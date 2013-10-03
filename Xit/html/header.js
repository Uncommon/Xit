function isCollapsed()
{
  return document.getElementById('committer').style.display == 'none'
}

function disclosure()
{
	var button = document.getElementById("triangle");
	var hidingIds = ['committer', 'sha', 'parents'];
	var newDisplay = 'none';
	var newImage = 'undisclosed.png'

	if (isCollapsed()) {
		newDisplay = 'block';
		newImage = 'disclosed.png'
	}
	for (index in hidingIds) {
		document.getElementById(hidingIds[index]).style.display = newDisplay;
	}
	button.src = newImage;
}
