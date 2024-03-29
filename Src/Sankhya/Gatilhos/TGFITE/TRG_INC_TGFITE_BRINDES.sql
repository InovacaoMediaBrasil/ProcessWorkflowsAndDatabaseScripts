USE [SANKHYA_PRODUCAO]
GO
/****** Object:  Trigger [sankhya].[TRG_INC_TGFITE_BRINDES]    Script Date: 15/05/2018 15:40:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*	=============================================
	Author: Rafael Turra Silva / Guilherme Branco
	Create date: 25/05/2016
	Description: Adiciona um produto brinde (Avental Condor - 12548) no pedido quando a somatória de itens da marca Condor for igual ou superior a R$100,00
	============================================= */

/*	==============================		ALTERACÕES		==============================
	Author: Rodrigo Lacalendola
	Create date: 20/09/2016
	Description: Além do brinde Condor, será tratado o de Crochê Irlandês [14069]
 
	Author: RAFAEL TURRA
	Create date: 24/10/2016
	Description: Retirada do brinde 14231 conforme chamado: DZ5-V6Q-V7AM
	
	Author: RODRIGO LACALENDOLA
	Create date: 06/03/2017
	Description: Campanha dia da Mulher - 02 presentes (15198 e 15199) nas compras acima de R$99

	Author: RODRIGO LACALENDOLA
	Create date: 07/08/2017
	Description: campanha Máquina SS988 - Brinde Patricia Washington

	Author: RODRIGO LACALENDOLA
	Create date: 16/08/2017
	Description: campanha Agosto Premiado

	Author: RODRIGO LACALENDOLA
	Create date: 04/12/2017
	Description: campanha My First Kit - dezembro/2017

	Author: RODRIGO LACALENDOLA
	Create date: 27/02/2018
	Description: Campanha dia V - 28/02/2018 - nas compras acima de R$59,90 o cliente ganha os brindes 17259 e 17258

	Author: RODRIGO LACALENDOLA
	Create date: 07/03/2018
	Description: Campanha dia V - 08/03/2018 - nas compras acima de R$59,90 o cliente ganha os brindes 17344

	Author: RODRIGO LACALENDOLA
	Create date: 07/05/2018
	Description: Campanha brinde 18032 nas compras acima de R$99

	Author: RODRIGO LACALENDOLA
	Create date: 14/05/2018
	Description: Campanha brinde 18005 nas compras de kits que estão nas mídias essa semana

	============================================= */

ALTER TRIGGER [sankhya].[TRG_INC_TGFITE_BRINDES] ON [sankhya].[TGFITE] AFTER INSERT,DELETE
AS
DECLARE
@NUNOTA			INT,
@CODTIPOPER		INT

BEGIN
	SET NOCOUNT ON;

	/* obtem o NUNOTA e o TOP do movimento inserido */
	SELECT	
			@NUNOTA = CAB.NUNOTA,
			@CODTIPOPER = CAB.CODTIPOPER
	FROM INSERTED ITE
	INNER JOIN TGFCAB CAB WITH(NOLOCK) ON (CAB.NUNOTA = ITE.NUNOTA)

		IF (@NUNOTA IS NULL)
			SELECT	
				@NUNOTA = CAB.NUNOTA,
				@CODTIPOPER = CAB.CODTIPOPER
			FROM deleted ITE
			INNER JOIN TGFCAB CAB WITH(NOLOCK) ON (CAB.NUNOTA = ITE.NUNOTA)

	-- SE FOR DAS TOPS DE VENDA, PROSSIGA
	IF (@CODTIPOPER IN (500,501,503,515))
		BEGIN

		-- DECLARANDO AS VARIÁVEIS PARA SOMAR OS BRINDES
		DECLARE 
		--@SOMABRINDE		FLOAT,
		--@CODPRODBRINDE	INT,
		@NUTAB INT,
		@VLRUNIT FLOAT,
		@VLRCUS FLOAT,
		@UF CHAR(2),
		@CODCFO INT	
	
		/************************************************/
		/*  INÍCIO BRINDE 18005		14/05 A 20/05	   */
		/************************************************/

		DECLARE @BRINDE1 INT, @VLRNOTA FLOAT, @VLRITE FLOAT, @EXISTEBRINDE1 CHAR(1), @DTNEG DATE, @EXISTEKIT CHAR(1)
		SET @EXISTEBRINDE1 = 'N'
		SET @BRINDE1 = 18005
		
		SELECT @DTNEG = DTNEG, @VLRNOTA = VLRNOTA, @VLRITE = VLRTOT
		FROM INSERTED I
		INNER JOIN sankhya.TGFCAB CAB WITH(NOLOCK) 
		ON CAB.NUNOTA = I.NUNOTA
	

		IF EXISTS (SELECT CODPROD FROM sankhya.TGFITE WITH(NOLOCK) WHERE NUNOTA = @NUNOTA AND CODPROD = @BRINDE1 AND USOPROD = 'B')
		SET @EXISTEBRINDE1 = 'S' ELSE SET @EXISTEBRINDE1 = 'N'
		
		IF @VLRNOTA + @VLRITE >= 99
			SET @EXISTEKIT = 'S';
		ELSE 
			SET @EXISTEKIT = 'N';

		/*IF EXISTS (SELECT CODPROD FROM INSERTED WITH(NOLOCK) WHERE CODPROD IN (7102,7334,10417,14410,14809,15102,15577,17188,17199,17202,17224,17271,17333,17870,18011,18023,18045,18122,18126))
		SET @EXISTEKIT = 'S' ELSE SET @EXISTEKIT = 'N'*/

		/* CASO TENHA ALGUM KIT DA CAMPANHA DURANTE O PERIODO, INSERE O BRINDE */
		IF (@DTNEG >= '14/05/2018' AND @DTNEG <= '20/05/2018' AND @EXISTEBRINDE1 = 'N' AND @EXISTEKIT = 'S')
		BEGIN


				/*************************** OBTENDO OS DADOS PARA FAZER O INSERT ******************************/

				-- DEFININDO O CFOP DA VENDA (LOCALIZANDO O ESTADO DO CLIENTE)
				SET @UF = (select TOP 1 UF.UF from sankhya.TGFITE I  WITH(NOLOCK)
							INNER JOIN sankhya.TGFCAB C  WITH(NOLOCK) ON C.NUNOTA = I.NUNOTA
							INNER JOIN sankhya.TGFPAR P  WITH(NOLOCK) ON P.CODPARC = C.CODPARC
							INNER JOIN sankhya.TSICID CID  WITH(NOLOCK) ON CID.CODCID = P.CODCID
							INNER JOIN sankhya.TSIUFS UF  WITH(NOLOCK) ON UF.CODUF = CID.UF
							WHERE I.NUNOTA = @NUNOTA)

				-- CASO FOR SAO PAULO, USAR O LOCAL - 5910
				IF @UF = 'SP'
					SET @CODCFO = 5910
				-- NOS DEMAIS UTILIZAR O CFOP 6910
				ELSE
					SET @CODCFO = 6910


				-- OBTENDO PREÇO DE VENDA




				/* VERIFICA SE EXISTE O BRINDE1 NO PEDIDO E SE O BRINDE TEM ESTOQUE*/
				IF (@EXISTEBRINDE1 = 'N' AND ((SELECT SUM(ESTOQUE)-SUM(RESERVADO) FROM sankhya.TGFEST WITH(NOLOCK) WHERE CODPROD = @BRINDE1) > 0 OR (SELECT AD_PESTNEG FROM sankhya.TGFPRO WITH(NOLOCK) WHERE CODPROD = @BRINDE1) = 'S'))
				BEGIN

				-- OBTENDO PREÇO DE CUSTO
				SET @VLRCUS = sankhya.PRECODECUSTO(@BRINDE1,'UN')

				-- OBTENDO PREÇO DE VENDA
				SELECT TOP 1 @NUTAB = NUTAB, @VLRUNIT = VLRVENDA FROM sankhya.TGFEXC WITH(NOLOCK)
				WHERE CODPROD = @BRINDE1
				ORDER BY NUTAB DESC

				/* INCLUI O BRINDE1 NO PEDIDO*/
				INSERT INTO sankhya.TGFITE (
				/*1*/NUTAB, NUNOTA, SEQUENCIA, CODEMP, CODPROD,
				/*2*/CODLOCALORIG, CONTROLE, USOPROD, CODCFO,QTDNEG,
				/*3*/QTDENTREGUE, QTDCONFERIDA, VLRUNIT, VLRTOT, VLRCUS,
				/*4*/BASEIPI, VLRIPI, BASEICMS, VLRICMS, VLRDESC,
				/*5*/BASESUBSTIT, VLRSUBST, ALIQICMS, ALIQIPI, PENDENTE,
				/*6*/CODVOL,ATUALESTOQUE, RESERVA,
				/*7*/STATUSNOTA, CODVEND,
				/*8*/VLRREPRED, VLRDESCBONIF, PERCDESC,
				/*9*/CODPARCEXEC, CUSTO, CODUSU, DTALTER
				) VALUES (
				/*1*/@NUTAB, @NUNOTA, ISNULL((SELECT MAX(SEQUENCIA) FROM sankhya.TGFITE WITH(NOLOCK) WHERE NUNOTA = @NUNOTA),0)+1, 1, @BRINDE1,
				/*2*/0, ' ', 'B',@CODCFO, 1,
				/*3*/0, 0, 0, 0, ISNULL(@VLRCUS,0),
				/*4*/0, 0, 0, 0, 0,
				/*5*/0, 0, 0, 0, 'S',
				/*6*/'UN', 1, 'S',
				/*7*/'A', 0,  
				/*8*/0, 0, 0,
				/*9*/0, ISNULL(@VLRCUS,0), 0, getdate()
				)
				END


			END

			/* CASO NÃO EXISTE KIT DA CAMPANHA NO PEDIDO */
			ELSE
			
				BEGIN

					IF EXISTS (SELECT CODPROD FROM deleted WITH(NOLOCK) WHERE CODPROD IN (7102,7334,10417,14410,14809,15102,15577,17188,17199,17202,17224,17271,17333,17870,18011,18023,18045,18122,18126))
					SET @EXISTEKIT = 'S' ELSE SET @EXISTEKIT = 'N'

							SELECT @DTNEG = DTNEG FROM DELETED D
							INNER JOIN sankhya.TGFCAB CAB WITH(NOLOCK) ON CAB.NUNOTA = D.NUNOTA


					IF(@DTNEG >= '14/05/2018' and @DTNEG <= '20/05/2018' AND @EXISTEKIT = 'S')

						BEGIN
						
							/* VERIFICA SE EXISTE O BRINDE1 NO PEDIDO, CASO EXISTA, DELETA. */
							IF EXISTS (SELECT CODPROD FROM sankhya.TGFITE WITH(NOLOCK) WHERE NUNOTA = @NUNOTA AND CODPROD = @BRINDE1 AND USOPROD = 'B')
							BEGIN	
							
								DELETE FROM sankhya.TGFITE WHERE NUNOTA = @NUNOTA AND CODPROD = @BRINDE1 AND USOPROD = 'B'
							END

						END

				END
			

		/************************************************/
		/*  FIM BRINDE 18005	14/05 A 20/05		   */
		/************************************************/


	END--IF TOPS DE VENDA (500 A 503)
END--IF FINAL