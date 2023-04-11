USE [SANKHYA_PRODUCAO]
GO

/****** Object:  StoredProcedure [dbo].[STP_CORRETORNFESEMFRETE]    Script Date: 29/05/2014 18:45:44 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Décio Bento
-- Create date: 2014-05-28
-- Description:	Corrige problemas fiscais na NF-e
-- =============================================
CREATE PROCEDURE [dbo].[STP_CORRETORNFESEMFRETE]
	@NUNOTA INT
AS

DECLARE

@VLRFRETE DECIMAL(5,2),
@SEQUENCIA INT,
@BASE DECIMAL(5,2),
@VALOR DECIMAL (5,2),
@VLRNOTA DECIMAL (5,2)
BEGIN
	SET NOCOUNT ON;



--2. Remover impostos do KIT, pois não vai na nota.

PRINT '2 - Zerando impostos do KIT'

UPDATE sankhya.TGFITE SET BASEICMS = 0, VLRICMS = 0, ALIQICMS = 0, ALIQICMSRED = 0
WHERE NUNOTA = @NUNOTA AND CODVOL = 'KT'

--3. Corrigir ICMS na TGFDIN de acordo com a TGFITE

PRINT '3 - Corrigindo Base do ICMS'
UPDATE sankhya.TGFDIN SET BASE = ITE.BASEICMS, BASERED = ITE.BASEICMS
FROM sankhya.TGFDIN DIN
INNER JOIN sankhya.TGFITE ITE ON (ITE.NUNOTA = DIN.NUNOTA AND ITE.SEQUENCIA = DIN.SEQUENCIA)
WHERE DIN.NUNOTA = @NUNOTA;

--4. UPDATE DIN -> SET VALOR = (BASE*ALIQ) / 100 (LEMBRAR DE FAZE CAST DECIMAL 5,2
PRINT '4 - Calcuando Impostos na TGFDIN'
DELETE sankhya.TGFDIN where nunota = @nunota and codinc = 0 and codimp = 1 
UPDATE sankhya.TGFDIN SET VALOR = CAST((BASE*ALIQUOTA)/100 AS DECIMAL(5,2))
WHERE NUNOTA = @NUNOTA;


--5. Corrigir ICMS de acordo com a soma das bases na TGFDIN
PRINT '5 - Corrigindo ICMS na TGFCAB'
SELECT @BASE = SUM(BASE), @VALOR = sum(VALOR)
FROM sankhya.TGFDIN
WHERE NUNOTA = @NUNOTA
AND CODINC = 1;

ALTER TABLE sankhya.tgfcab disable trigger all;
UPDATE sankhya.TGFCAB
SET BASEICMS = @BASE, VLRICMS = (@base * 0.18), BASEICMSFRETE = 0, ICMSFRETE = 0
where nunota = @NUNOTA;
ALTER TABLE sankhya.tgfcab enable trigger all;


--6. Corrigir valor total da Nota

PRINT '6 - Corrigindo Total da NF-E'

SELECT @VLRNOTA = SUM(VLRTOT - VLRDESC)
FROM sankhya.TGFITE
WHERE NUNOTA = @NUNOTA 
AND CODVOL <> 'KT'

ALTER TABLE sankhya.TGFCAB disable trigger all
UPDATE sankhya.TGFCAB
SET VLRNOTA = @VLRNOTA
WHERE NUNOTA = @NUNOTA
ALTER TABLE sankhya.TGFCAB ENABLE TRIGGER ALL

--1. PRIMEIRA INSTRUÇÃO
--
--Zerar valor do frete e impostos sobre o frete
--
--
--
	
PRINT '1 - Zerando Frete e impostos sobre frete'
	
ALTER TABLE sankhya.TGFCAB DISABLE TRIGGER ALL
UPDATE sankhya.TGFCAB

SET VLRFRETE = 0.0

WHERE NUNOTA = @NUNOTA
ALTER TABLE sankhya.TGFCAB ENABLE TRIGGER ALL

DELETE sankhya.TGFDIN 
WHERE NUNOTA = @NUNOTA
AND CODINC = 3;

END

GO

