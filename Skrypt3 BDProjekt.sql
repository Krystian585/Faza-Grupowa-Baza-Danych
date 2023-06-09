USE master
GO
CREATE LOGIN Zmieniacz WITH PASSWORD='P@ssw0rd', CHECK_POLICY = OFF,
	CHECK_EXPIRATION = OFF
USE BDProjekt
GO
CREATE USER Zmieniacz
GO
USE BDProjekt
GO
SP_ADDROLEMEMBER 'db_datareader','Zmieniacz'
GO
SP_ADDROLEMEMBER 'db_datawriter','Zmieniacz'

DENY DELETE ON ZAWODNIK TO Zmieniacz

--SP_HELPROTECT

-- REVOKE DELETE ON ZAWODNIK TO Zmieniacz
-- DROP USER Zmieniacz
-- DROP LOGIN Zmieniacz

CREATE DEFAULT BRAK_INFO AS 'Brak Informacji'
GO
EXEC sp_bindefault BRAK_INFO, 'ZAWODNIK.WIEK'

--EXEC SP_UNBINDEFAULT 'ZAWODNIK.WIEK'
-- DROP DEFAULT BRAK_INFO

GO
CREATE RULE PLEC_X AS @X IN ('M','K')
GO
EXEC sp_bindrule PLEC_X, 'ZAWODNIK.PLEC'

--EXEC sp_unbindrule'ZAWODNIK.PLEC'
--DROP RULE PLEC_X

IF OBJECT_ID('tempdb..#minuty') IS NOT NULL DROP TABLE #minuty
SELECT IDZAWODNIKA
	,SUM(MINUTY) as Minuty
INTO #minuty
FROM STATYZAW
GROUP BY IDZAWODNIKA
SELECT 
	Z.IDZAWODNIKA
	,Z.NAZWISKO
	,Z.IMIE
	,R.NAZWA
	,SUM(S.GOLE) AS 'Liczba Goli'
	,SUM(S.ASYSTY) AS 'Liczba Asyst'
	,M.Minuty
	,DENSE_RANK() OVER(ORDER BY SUM(S.GOLE) DESC, SUM(S.ASYSTY)DESC ,M.MINUTY DESC  ) AS MIEJSCE
FROM ZAWODNIK AS Z JOIN REPREZENTACJA AS R ON Z.IDREPREZENTACJA=R.IDREPREZENTACJA
JOIN STATYZAW AS S ON S.IDZAWODNIKA=Z.IDZAWODNIKA
JOIN #minuty AS M ON M.IDZAWODNIKA = Z.IDREPREZENTACJA
WHERE S.GOLE>0 OR S.ASYSTY >0
GROUP BY Z.NAZWISKO, Z.IMIE, R.NAZWA, Z.IDZAWODNIKA, M.Minuty

--SELECT * FROM MECZ

--SELECT * FROM STATYZAW WHERE IDZAWODNIKA = 73 
--SELECT * FROM MECZ WHERE IDMECZ = 2
--SELECT * FROM ZAWODNIK WHERE IDZAWODNIKA =70
--SELECT * FROM ZAWODNIK WHERE IDZAWODNIKA = 54
--SELECT * FROM ZAWODNIK WHERE IDREPREZENTACJA=4
--SELECT * FROM STATYZAW WHERE IDDANE =162

CREATE VIEW KALENDARZ
AS
WITH DATY AS
(
SELECT CAST('20221120' AS DATE) AS DZIEN
UNION ALL
SELECT DATEADD(DAY,1,DZIEN) AS DZIEN
FROM DATY
WHERE DZIEN <'20221202'
)
SELECT D.DZIEN
	,CONVERT(varchar(5),CAST(M.DATAW AS TIME)) AS GODZINA
	,R.NAZWA AS GOSPODARZ
	,R2.NAZWA AS GOSC
FROM MECZ AS M RIGHT JOIN DATY AS D ON CAST(M.DATAW AS DATE) = D.DZIEN 
LEFT JOIN REPREZENTACJA AS R ON M.GOSPODARZ_ID = R.IDREPREZENTACJA
LEFT JOIN REPREZENTACJA AS R2 ON M.GOSC_ID = R2.IDREPREZENTACJA
GROUP BY D.DZIEN, M.DATAW, R.NAZWA, R2.NAZWA

SELECT * FROM REPREZENTACJA
	
--SELECT * FROM KALENDARZ
--DROP VIEW KALENDARZ

CREATE VIEW TABELA_WYNIKOW
AS
WITH WYGRANE_CTE
AS
(
SELECT GOSPODARZ_ID as DRUZYNA_ID
	,BRAMKI_GOSP AS STRZELONE
	,BRAMKI_GOSC AS STRACONE
	,BRAMKI_GOSP-BRAMKI_GOSC AS BILANS
FROM MECZ
UNION ALL
SELECT GOSC_ID as DRUZYNA_ID
	,BRAMKI_GOSC AS STRZELONE
	,BRAMKI_GOSP AS STRACONE
	,BRAMKI_GOSC-BRAMKI_GOSP AS BILANS
FROM MECZ
),
PUNKTY_CTE
AS
(
SELECT * 
	,case 
		WHEN BILANS>0 THEN 3
		WHEN BILANS=0 THEN 1
		ELSE 0
		END AS PUNKTY
FROM WYGRANE_CTE
)
SELECT 
	UPPER(R.NAZWA) AS Reprezentacja
	,SUM(PUNKTY) AS Punkty
	,COUNT(*) AS 'Liczba Meczy'
	,SUM(STRZELONE) AS Strzelone
	,SUM(STRACONE) AS Stracone
	,SUM(BILANS) AS Bilans
FROM PUNKTY_CTE AS P 
JOIN REPREZENTACJA AS R ON R.IDREPREZENTACJA = P.DRUZYNA_ID
GROUP BY R.NAZWA

SELECT * FROM TABELA_WYNIKOW
Order by Punkty DESC, Bilans DESC

CREATE FUNCTION DRUZYNA_ZMECZENIE (@NAZWA CHAR(30))
RETURNS TABLE 
AS
	RETURN(SELECT Z.NAZWISKO,Z.IMIE, SUM(S.MINUTY) AS 'Zagrane minuty'
			FROM ZAWODNIK AS Z JOIN STATYZAW AS S ON Z.IDZAWODNIKA = S.IDZAWODNIKA
			JOIN REPREZENTACJA AS R ON R.IDREPREZENTACJA = Z.IDREPREZENTACJA
			WHERE R.NAZWA = @NAZWA
			GROUP BY Z.NAZWISKO, Z.IMIE)
			

--DROP FUNCTION DRUZYNA_ZMECZENIE
--SELECT * FROM DRUZYNA_ZMECZENIE('POLSKA') ORDER BY 'Zagrane minuty'DESC

CREATE FUNCTION OCENA_ZAWODNIKA (@IDZAWODNIKA INT, @IDMECZ INT)
RETURNS nvarchar(70)
AS
BEGIN 
	DECLARE @PELNA_NAZWA nvarchar(70)
	SELECT @PELNA_NAZWA = Z.NAZWISKO + Z.IMIE + CAST(S.OCENA AS CHAR(10))
	FROM ZAWODNIK AS Z JOIN STATYZAW AS S ON S.IDZAWODNIKA = Z.IDZAWODNIKA
	WHERE S.IDZAWODNIKA = @IDZAWODNIKA AND S.IDMECZ = @IDMECZ
	RETURN (@PELNA_NAZWA)
END
--SELECT dbo.OCENA_ZAWODNIKA(3,1)
--DROP FUNCTION OCENA_ZAWODNIKA

CREATE TRIGGER BLOKADA_MECZ
ON MECZ
INSTEAD OF UPDATE, DELETE, INSERT
AS
THROW 50001, 'Nalozona blokada',2

GO
INSERT INTO MECZ(DATAW,GOSPODARZ_ID,GOSC_ID,BRAMKI_GOSP,BRAMKI_GOSC) VALUES
	('2022-11-22 17:00',2,1,0,0)



DECLARE Minuty CURSOR
	LOCAL
	FOR SELECT Z.NAZWISKO,Z.IMIE, SUM(S.MINUTY) AS 'Zagrane minuty'
			FROM ZAWODNIK AS Z JOIN STATYZAW AS S ON Z.IDZAWODNIKA = S.IDZAWODNIKA
			JOIN REPREZENTACJA AS R ON R.IDREPREZENTACJA = Z.IDREPREZENTACJA
			GROUP BY Z.NAZWISKO, Z.IMIE
			ORDER BY SUM(S.MINUTY) DESC
DECLARE @a char(30)
	,@b char(30)
	,@c int
OPEN Minuty
FETCH Minuty into @a, @b, @c
WHILE @@FETCH_STATUS = 0
	BEGIN 
		PRINT CONCAT(@a,'',@b,@c)
		FETCH Minuty into @a,@b,@c
	END
CLOSE Minuty
DEALLOCATE Minuty
GO

