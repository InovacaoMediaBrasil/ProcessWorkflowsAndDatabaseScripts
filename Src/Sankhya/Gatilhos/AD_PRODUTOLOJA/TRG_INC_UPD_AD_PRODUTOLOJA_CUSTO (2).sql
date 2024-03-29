USE [SANKHYA_PRODUCAO]
GO
/****** Object:  Trigger [sankhya].[TRG_INC_UPD_AD_PRODUTOLOJA_CUSTO]    Script Date: 30/08/2017 16:13:11 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*	=============================================
	Author:			Rodrigo Lacalendola
	Create date:	30/08/2017
	Description:	Verifica se o produto tem preço de custo cadastrado
	============================================= */
ALTER TRIGGER [sankhya].[TRG_INC_UPD_AD_PRODUTOLOJA_CUSTO]
   ON  [sankhya].[AD_PRODUTOLOJA] 
   AFTER INSERT, UPDATE
AS 
DECLARE
@CODPROD INT,
@ATIVO CHAR(1),
@PRECOBRANCO CHAR(1),
@CODVOL CHAR(2),
@CUSTO FLOAT,
@ERRMSG VARCHAR(100),
@SOLICITANTE CHAR(30)

BEGIN
	SET NOCOUNT ON;
	
	IF UPDATE(ATIVO)
	BEGIN
			/* OBTEM OS DADOS DA ALTERAÇÃO/INCLUSÃO */
			SELECT	@CODPROD =		I.CODPROD, 
					@ATIVO =		I.ATIVO
					FROM INSERTED AS I

			/* OBTEM A UNIDADE DO PRODUTO ALTERADO */
			SELECT @CODVOL = CODVOL FROM sankhya.TGFPRO WITH(NOLOCK) WHERE CODPROD = @CODPROD
			
		
			/* SE ESTIVER ATIVANDO UM PRODUTO QUE NÃO É KIT */
			IF (@ATIVO = 'S' AND @CODVOL != 'KT')
			BEGIN

						
			/* OBTEM O PREÇO DE CUSTO */
			SELECT @CUSTO = sankhya.PRECODECUSTO(@CODPROD,@CODVOL)


			/* SE O CUSTO FOR NULO OU ZERO */
			IF ISNULL(@CUSTO,0) = 0
				BEGIN
					/* CASO ESJA, EXIBE MENSAGEM DE ERRO */
					SET @ERRMSG = 'Não pode ser liberado para venda porque o produto não tem preço de custo cadastrado.'
					GOTO ERROR
				END
			END

	
			RETURN


			ERROR:
			EXEC SANKHYA.SNK_ERROR @ERRMSG

			(SELECT @SOLICITANTE = program_name
			FROM MASTER.DBO.SYSPROCESSES
			WHERE SPID = @@SPID)

			IF (UPPER(@SOLICITANTE) LIKE 'MICROSOFT%') OR
						(@SOLICITANTE = 'MS SQLEM') OR 
						(@SOLICITANTE = 'MS SQL QUERY ANALYZER') OR
				(UPPER(@SOLICITANTE) LIKE 'TOAD%')
			ROLLBACK  TRANSACTION
	
	END

END