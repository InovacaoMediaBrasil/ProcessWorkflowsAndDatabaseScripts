USE [SANKHYA_PRODUCAO]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Rafael Turra Silva
-- Create date: 2017-10-25
-- Description:	<Realiza o insert de KIT na TGFCOI2, pois o KIT não é necessário conferir e sim os componentes.>
-- =============================================
CREATE TRIGGER [sankhya].[TRG_INC_TGFCON2_CONF_KIT] 
   ON  [sankhya].[TGFCON2]
   AFTER INSERT
AS 
DECLARE


@NUCONF INT,
@STATUS CHAR(1),
@NUNOTA INT,
@CODPROD INT,
@CODVOL CHAR (2),
@QTDNEG FLOAT,
@SEQ INT

BEGIN
	SET NOCOUNT ON;

	/* Obtem os dados da nota a ser conferida */
	SELECT	@NUCONF = I.NUCONF,
			@STATUS = I.STATUS,
			@NUNOTA = I.NUNOTAORIG
	FROM	INSERTED I

SET @SEQ = 1

	/* Cursor para verificar se os itens da nota são ou não KITs */
DECLARE KITS CURSOR FAST_FORWARD FOR

	/* Obtem os dados da nota que foi inserida */
SELECT  I.CODPROD, I.CODVOL, I.QTDNEG
	FROM	TGFITE I
	WHERE	I.NUNOTA = @NUNOTA
			AND I.CODVOL = 'KT'

OPEN KITS 

FETCH NEXT FROM KITS INTO @CODPROD, @CODVOL, @QTDNEG

WHILE @@FETCH_STATUS = 0

	BEGIN
		
		/* Realiza um insert na TGFCOI2 colocando o KIT como conferido, igual a quantidade da ITE */

		INSERT INTO TGFCOI2 (NUCONF, SEQCONF, CODBARRA, CODPROD, CODVOL, CONTROLE, QTDCONFVOLPAD, QTDCONF)
		VALUES (@NUCONF, @SEQ, @CODPROD, @CODPROD, @CODVOL, '', @QTDNEG, @QTDNEG)
		
		SET @SEQ = @SEQ + 1
		
		FETCH NEXT FROM KITS INTO @CODPROD, @CODVOL, @QTDNEG
	END

END