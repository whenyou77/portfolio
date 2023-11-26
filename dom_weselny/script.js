function oblicz()
{
	let liczba = parseInt(document.getElementById("liczba").value);
	let popraw = document.getElementById("popraw").checked;
	
	let wynik = popraw ? (liczba*100)*1.3 : (liczba*100) ;
	
	document.getElementById("wynik").innerHTML = "Koszt Twojego wesela to " + wynik + " złotych"
	
	console.log(wynik)
}