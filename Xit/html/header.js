function disclosure()
{
	var button = document.getElementById("triangle");
	var hidingIds = ['committer', 'sha', 'parents'];
	var newDisplay = 'none';
	var newImage = 'undisclosed.png'

	if (document.getElementById(hidingIds[0]).style.display == 'none') {
		newDisplay = 'block';
		newImage = 'disclosed.png'
	}
	for (index in hidingIds) {
		document.getElementById(hidingIds[index]).style.display = newDisplay;
	}
	button.src = newImage;
}
