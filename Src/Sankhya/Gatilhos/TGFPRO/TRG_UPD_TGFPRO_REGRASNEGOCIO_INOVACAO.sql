USE [SANKHYA_PRODUCAO]
GO
/****** Object:  Trigger [sankhya].[TRG_UPD_TGFPRO_REGRASNEGOCIO_INOVACAO]    Script Date: 03/10/2018 19:21:23 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*	=============================================
	Author:			Rodrigo Lacalendola
	Create date:	2017-07-04
	Description:	Trigger para ser incluído regras gerais de cadastro / regras de negócio da Inovação.

	Author:			Rodrigo Lacalendola
	Update date:	2018-04-27
	Description:	incluído as regras #3 e #4.

	
	Author:			Rodrigo Lacalendola
	Update date:	2018-05-02
	Description:	na regra #4 inserido informação de qual problema no EAN (duplicado, vazio, etc);



	Lista de regras: (atualizado em 2018-04-27)

	#1 Não é permitido cadastrar um produto sem peso

	#2 ST cadastrado incorreto

	#3 Configurações de IPI incorretas

	#4 Situação do EAN incorreta



	

	=============================================*/
ALTER TRIGGER [sankhya].[TRG_UPD_TGFPRO_REGRASNEGOCIO_INOVACAO] 
   ON  [sankhya].[TGFPRO] 
   AFTER INSERT,UPDATE
AS 
DECLARE 
@CODPROD INT,
@ATIVO CHAR(1),
@PESOLIQ INT,
@PESOBRUTO INT,
@GRUPOICMS INT,
@TIPSUBST CHAR(1),
@CODVOL	CHAR(2),
@CODGRUPOPROD INT,
@CLASSUBTRIB INT,
@ERRMSG VARCHAR(200),
@CSTIPIENT INT,
@CSTIPISAI INT,
@TEMIPICOMPRA CHAR(1),
@TEMIPIVENDA CHAR(1),
@EAN VARCHAR(20),
@CODIPI INT
BEGIN
	SET NOCOUNT ON;

	/*
	 *	Obtém as informações do produto na TGFPRO (INSERTED)
	 */
	SELECT	@CODPROD =		I.CODPROD, 
			@ATIVO =		I.ATIVO, 
			@PESOLIQ =		I.PESOLIQ,
			@PESOBRUTO =	I.PESOBRUTO,
			@GRUPOICMS =	I.GRUPOICMS,
			@TIPSUBST =		I.TIPSUBST,
			@CODVOL =		I.CODVOL,
			@CODGRUPOPROD =	I.CODGRUPOPROD,
			@CLASSUBTRIB =  I.CLASSUBTRIB,
			@CSTIPIENT	=	I.CSTIPIENT,
			@CSTIPISAI	=	I.CSTIPISAI,
			@TEMIPICOMPRA =	I.TEMIPICOMPRA,
			@TEMIPIVENDA =	I.TEMIPIVENDA,
			@EAN		=   I.REFERENCIA,
			@CODIPI		=   I.CODIPI
	FROM INSERTED AS I
	

	 	IF @ATIVO = 'S' AND @CODVOL != 'KT' AND @CODGRUPOPROD NOT IN (720000, 800000)
		BEGIN




			/*
			#1 Não é permitido cadastrar produto sem peso
			*/
			IF @PESOBRUTO IS NULL OR @PESOLIQ IS NULL 
			BEGIN
				
				SET @ERRMSG = 'Produto ' + CAST(@CODPROD AS VARCHAR) + ' não pode ser salvo sem PESO (líquido e bruto).'
				RAISERROR( @ERRMSG , 16, 10 )   
				RETURN

			END


			/*
			#2 ST cadastrado incorreto
			 */
			IF sankhya.FN_VERIFICA_ST(@CODPROD) LIKE '%ERRO%'
			BEGIN
				
				SET @ERRMSG = 'A regra de ST está incorreta no produto ' + CAST(@CODPROD AS VARCHAR) + ', favor verificar.'
				RAISERROR( @ERRMSG , 16, 10 )   
				RETURN

			END

			/*
			#3 Configurações de IPI incorretas
			 */
			 /* Configuração de IPI de saída (obrigatório ser 53) */
			 IF (ISNULL(@CSTIPISAI,0) != 53)
			 BEGIN
				
				SET @ERRMSG = 'A regra de IPI está incorreta no produto ' + CAST(@CODPROD AS VARCHAR) + '. Para todos os produtos o CST do IPI de saída precisa ser  53 - Saída não tributada.'
				RAISERROR( @ERRMSG , 16, 10 )   
				RETURN
			  END

	
			/* Configuração de IPI de entrada (inconsistências no preenchimento) */
			IF (ISNULL(@CSTIPIENT,0) = 49 AND ISNULL(@TEMIPICOMPRA,'N') = 'N') OR (ISNULL(@CSTIPIENT,0) = -1 AND ISNULL(@TEMIPICOMPRA,'N') = 'S') OR
			   (ISNULL(@CSTIPIENT,0) = 49 AND ISNULL(@CODIPI,0) = 0) OR (ISNULL(@CSTIPIENT,0) = -1 AND ISNULL(@CODIPI,0) > 0) OR
				ISNULL(@CSTIPIENT,0) NOT IN (-1,49)
			 BEGIN
				
				SET @ERRMSG = 'A regra de IPI de entrada está incorreta no produto ' + CAST(@CODPROD AS VARCHAR) + ', favor verificar os campos Tem IPI na compra, IPI e CST Ipi Entrada na aba Impostos.'
				RAISERROR( @ERRMSG , 16, 10 )   
				RETURN
			  END



			  /*
			 #4 Situação do EAN incorreta
			 */
			 IF sankhya.FN_VERIFICA_EAN(@CODPROD) != 'OK'
			 BEGIN
				
				DECLARE @TIPOERROEAN VARCHAR(20);
				SET @TIPOERROEAN = sankhya.FN_VALIDA_EAN(@EAN)

				SET @ERRMSG = 'O EAN está incorreto no produto ' + CAST(@CODPROD AS VARCHAR) + ', favor verificar [' +  RTRIM(LTRIM(@TIPOERROEAN)) + ']';
				RAISERROR( @ERRMSG , 16, 10 )   
				RETURN
			  END



		-- END ATIVO, GRUPO PROD E KIT
		END



	

--END FINAL	
END
