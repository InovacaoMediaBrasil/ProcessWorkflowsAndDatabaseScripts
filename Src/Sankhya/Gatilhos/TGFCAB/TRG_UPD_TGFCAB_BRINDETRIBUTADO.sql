USE [SANKHYA_PRODUCAO]
GO
/****** Object:  Trigger [sankhya].[TRG_UPD_TGFCAB_BRINDETRIBUTADO]    Script Date: 29/08/2018 13:04:53 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER TRIGGER [sankhya].[TRG_UPD_TGFCAB_BRINDETRIBUTADO] ON [sankhya].[TGFCAB] FOR INSERT, UPDATE
AS
DECLARE
@NUNOTA			INT,
@VLRFRETE		FLOAT,
@VLRNOTA		FLOAT,
@VLRITENS		FLOAT,
@VLRJURO		FLOAT,
@CODTIPOPER		INT,
@CODPARC		INT

BEGIN

	/* Obtém os dados do Pedido  */
	SELECT	@NUNOTA =		I.NUNOTA, 
			@VLRNOTA =		I.VLRNOTA, 
			@VLRFRETE =		I.VLRFRETE,
			@VLRJURO =		I.VLRJURO, 
			@VLRITENS =		SUM(ITE.VLRTOT - ITE.VLRDESC), 
			@CODTIPOPER =	I.CODTIPOPER, 
			@CODPARC =		I.CODPARC
	FROM INSERTED I WITH(NOLOCK)
	INNER JOIN sankhya.TGFITE ITE WITH(NOLOCK) 
	ON ITE.NUNOTA = I.NUNOTA
	AND ITE.USOPROD = 'R'
	GROUP BY I.NUNOTA, I.VLRNOTA, I.VLRFRETE, I.VLRJURO, I.CODTIPOPER, I.CODPARC

	/* Caso não altere o valor da nota, ou não seja das TOPS de pedido, retorna.*/
	IF (NOT UPDATE(VLRNOTA)) 
	AND @CODTIPOPER NOT IN (500,501,502,503,515,505,550,561,562)
		RETURN

	/* Se for uma top de PEDIDO DE VENDA e estiver sendo cobrado o valor do brinde,
		ou seja, o valor total do pedido esteja incluindo os brindes,
		atualiza o valor para que seja apenas a soma do valor dos itens mais o frete */
	IF (@VLRNOTA != (@VLRITENS + @VLRFRETE + @VLRJURO) 
	AND @@NESTLEVEL < 6 
	AND @CODTIPOPER IN (500,501,502,503,515))
		UPDATE sankhya.TGFCAB 
		SET VLRNOTA = @VLRITENS + @VLRFRETE + @VLRJURO
		WHERE NUNOTA = @NUNOTA

	/* Se for uma top de NOTA DE VENDA e NÃO estiver sendo cobrado o valor do brinde,
		adiciona o brinde ao valor total para ser tributado */
	IF (@VLRNOTA != (@VLRITENS + @VLRFRETE + @VLRJURO) 
	AND @@NESTLEVEL < 6 
	AND @CODTIPOPER IN (550,561,562))
	BEGIN

		/* Obtém os dados dos itens do pedido  */
		SELECT @VLRITENS = SUM(VLRTOT-VLRDESC)
		FROM INSERTED I WITH(NOLOCK) 
		INNER JOIN sankhya.TGFITE ITE WITH(NOLOCK) 
		ON ITE.NUNOTA = I.NUNOTA AND ITE.USOPROD IN ('R','B')

		/* Atualiza o valor, para tributar o brinde */
		UPDATE sankhya.TGFCAB 
		SET VLRNOTA = @VLRITENS + @VLRFRETE + @VLRJURO
		WHERE NUNOTA = @NUNOTA
	END	
END